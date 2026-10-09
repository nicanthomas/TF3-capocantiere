"""
Capo Cantiere - middleware CLI per Transport Fever 3.

Tu scrivi direttive in italiano ("fammi una linea tram a Borgo Pace"), Claude le traduce in
chiamate ai tool; i tool di costruzione diventano azioni per la mod Lua in gioco, dopo la tua conferma.

Installazione (una volta):
    pip install anthropic

Chiave API: crea una chiave su https://console.anthropic.com e impostala come variabile d'ambiente
(non scriverla nel codice). In PowerShell, per la sessione corrente:
    $env:ANTHROPIC_API_KEY = "sk-ant-..."
oppure in modo permanente:
    setx ANTHROPIC_API_KEY "sk-ant-..."     (poi riapri il terminale)

Avvio (con la partita aperta e la mod "Capo Cantiere" attiva):
    python main.py

Comandi speciali nella console:
    /stato    riassunto della mappa (senza usare Claude)
    /ping     verifica che la mod risponda
    /reset    dimentica la conversazione
    /esci     esce

Registro delle azioni: <dati utente>/capocantiere/log/azioni_AAAA-MM.jsonl
"""

from __future__ import annotations

import json
import os
import sys
import time

from action_log import log_action
from collaudo import Collaudo, format_report
from conversation import cached_request, summarize_history, trim_history, validate_args
from game_bridge import GameBridge, find_entities, overview
from journal import Journal
from tools import LOCAL_TOOLS, SPENDING_TOOLS, TOOLS, describe_action
from tools_bozza import format_plan
from versione import check_versions

# Azioni della bozza (dev-notes/bozza, non ancora provate in gioco): solo con la variabile CAPOCANTIERE_BOZZA=1
# e con la mod costruita includendo la bozza.
USE_BOZZA = os.environ.get("CAPOCANTIERE_BOZZA") == "1"
READ_TOOLS: set = set()
if USE_BOZZA:
    from tools_bozza import LOCAL_TOOLS_BOZZA, READ_TOOLS_BOZZA, SPENDING_TOOLS_BOZZA, SYSTEM_PROMPT_BOZZA, TOOLS_BOZZA
    TOOLS = TOOLS + TOOLS_BOZZA
    SPENDING_TOOLS = SPENDING_TOOLS | SPENDING_TOOLS_BOZZA
    LOCAL_TOOLS = LOCAL_TOOLS | LOCAL_TOOLS_BOZZA
    READ_TOOLS = set(READ_TOOLS_BOZZA)

TOOLS_BY_NAME = {t["name"]: t for t in TOOLS}

# Modello Anthropic: predefinito qui, oppure variabile d'ambiente CAPOCANTIERE_MODEL.
MODEL = os.environ.get("CAPOCANTIERE_MODEL", "claude-sonnet-5-5")
# Avviso quando i token della sessione superano questa soglia (variabile CAPOCANTIERE_TOKEN_WARN; 0 = mai).
TOKEN_WARN = int(os.environ.get("CAPOCANTIERE_TOKEN_WARN", "500000"))
USAGE = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0, "calls": 0}


def add_usage(resp) -> None:
    """Somma i token di una risposta e stampa il totale della sessione (per misurare il costo reale)."""
    u = getattr(resp, "usage", None)
    if u is None:
        return
    USAGE["input"] += getattr(u, "input_tokens", 0) or 0
    USAGE["output"] += getattr(u, "output_tokens", 0) or 0
    USAGE["cache_read"] += getattr(u, "cache_read_input_tokens", 0) or 0
    USAGE["cache_write"] += getattr(u, "cache_creation_input_tokens", 0) or 0
    USAGE["calls"] += 1


def usage_line() -> str:
    tot = USAGE["input"] + USAGE["output"] + USAGE["cache_read"] + USAGE["cache_write"]
    return (f"[token sessione] chiamate {USAGE['calls']}, input {USAGE['input']}, output {USAGE['output']}, "
            f"cache letta {USAGE['cache_read']}, cache scritta {USAGE['cache_write']} (totale {tot})")
MAX_TOKENS = 4096
MAX_TOOL_ROUNDS = 12           # limite di sicurezza ai giri di tool per una singola richiesta
MAX_TURNS = 8                  # turni di conversazione tenuti per intero (i piu' vecchi diventano un riassunto)
UNDO_PHASE_PAUSE = 3.0         # secondi tra le fasi di "annulla" (il gioco deve elaborare la fase prima)
MAX_AUTO_CHECKS = 5            # collaudi automatici (dopo 1-2 mesi di gioco) per ogni turno dell'utente

SYSTEM_PROMPT = """Sei il "Capo Cantiere" di una partita a Transport Fever 3 (l'anno corrente e' in get_overview:
la mod sceglie da sola veicoli, binari e stazioni adatti all'epoca).
L'utente e' il direttore della compagnia: ti da' direttive strategiche in italiano e tu le esegui
usando i tool. Non giochi da solo: fai solo quello che ti viene chiesto.

Regole:
- Rispondi sempre in italiano, in modo breve e concreto.
- Prima di costruire, risolvi ogni nome con find_entity e usa gli id. Se un nome e' ambiguo, chiedi quale.
- Spiega in una o due frasi il piano prima di chiamare i tool che costruiscono o comprano.
- I tool che spendono soldi vengono confermati dall'utente: se rifiuta, non insistere e proponi alternative.
- Se un'azione fallisce o non e' ancora supportata dalla mod, dillo chiaramente e non inventare risultati.
- Coordinate in metri (x, y); distanze in linea d'aria.
- Per servire una citta' con il trasporto passeggeri usa build_bus_line (fa tutto: fermate, deposito,
  linea, veicoli). Usa build_station + build_line + buy_and_assign_vehicles solo per linee su misura.
- Per il tram usa build_tram_line; riporta all'utente le fermate scartate (campo log del risultato).
- Per le merci usa connect_industry_to_city (solo su strada, transport=truck). Controlla prima con get_overview chi usa
  quella merce: un'industria con quella merce tra gli input, oppure una citta' se e' in townAcceptedCargo.
- Per collegare citta' in treno usa build_rail_line con gli id nell'ordine del percorso (preferisci
  citta' a 1-6 km l'una dall'altra). La mod costruisce da sola ponti, gallerie, sovrappassi; binario unico con
  stazioni a 2 binari dove i treni si incrociano: al massimo un treno per stazione (dillo se ne chiede di piu'). Se fallisce, riporta
  l'errore e proponi un'altra coppia di citta' o un collegamento su strada. I treni merci non sono ancora supportati.
- Le industrie hanno gia' una propria stazione merci per camion.
"""
if USE_BOZZA:
    SYSTEM_PROMPT += SYSTEM_PROMPT_BOZZA


def ask_plan(args: dict) -> dict:
    """Mostra il piano proposto da Claude e raccoglie la risposta dell'utente (si', no, o modifiche)."""
    print("\n  >>> Piano proposto:")
    print(format_plan(args))
    ans = input("  Confermi il piano? (s = si', n = no, oppure scrivi cosa cambiare) ").strip()
    low = ans.lower()
    if low in ("s", "si", "sì", "y", "yes", "ok"):
        return {"approved": True}
    if low in ("n", "no", ""):
        return {"approved": False}
    return {"approved": False, "feedback": ans}


def run_local_tool(name: str, args: dict, bridge: GameBridge) -> dict:
    if name == "propose_plan":
        return ask_plan(args)
    state = bridge.state()
    if name == "find_entity":
        return {"results": find_entities(state, args.get("query", ""), args.get("kind", "any"))}
    if name == "get_overview":
        return overview(state)
    return {"error": f"tool locale sconosciuto: {name}"}


def confirm(text: str) -> bool:
    print(f"\n  >>> {text}")
    ans = input("  Confermi? (s/n) ").strip().lower()
    return ans in ("s", "si", "sì", "y", "yes")


def run_game_tool(name: str, args: dict, bridge: GameBridge) -> dict:
    if bridge.state().get("speed") == 0:                 # la mod v14 esporta la velocita' del gioco
        return {"ok": False, "error": "La partita e' in pausa: chiedi all'utente di riprendere il gioco e riprova."}
    journal = Journal(bridge.data_folder)
    entry = None
    if name == "undo_last_action":
        entry = journal.last_undoable()
        if not entry:
            return {"ok": False, "error": "Non c'e' nessuna azione da annullare nel registro."}
    if name in SPENDING_TOOLS:
        text = describe_action(name, args, bridge.state())
        if entry:
            text += f" -> {entry['type']} delle {entry['time']}"
        if not confirm(text):
            return {"ok": False, "cancelled": True, "message": "Annullato dall'utente."}
    if entry:
        action = {"type": "undo", "created": entry["created"]}
    else:
        action = {"type": name}
        action.update(args)
        if name == "check_line_fleet":                 # stessa azione della mod, solo proposta
            action["type"] = "adjust_line_fleet"
            action["apply"] = False
        elif name == "adjust_line_fleet":
            action["apply"] = True
    if name not in READ_TOOLS:
        print("  (in costruzione: puo' richiedere fino a qualche minuto...)")
    t0 = time.time()
    try:
        results = bridge.send([action], timeout=330)   # la mod aspetta fino a 300 s
    except TimeoutError as e:
        result = {"ok": False, "error": str(e)}
        _log(bridge, name, args, result, time.time() - t0)
        return result
    result = results[0] if results else {"ok": False, "error": "nessun risultato"}
    _log(bridge, name, args, result, time.time() - t0)
    # "annulla" lavora a fasi (veicoli e linee, poi binari, poi costruzioni), una per richiesta: toglierle tutte nello
    # stesso momento fa crashare il gioco. Si ripete finche' la mod risponde done (al massimo 3 fasi).
    phases = 1
    while entry and isinstance(result, dict) and result.get("ok") and result.get("done") is False and phases < 3:
        time.sleep(UNDO_PHASE_PAUSE)
        try:
            more = bridge.send([action], timeout=330)
        except TimeoutError as e:
            result = {"ok": False, "error": str(e)}
            break
        result = more[0] if more else {"ok": False, "error": "nessun risultato"}
        phases += 1
        _log(bridge, name, args, result, 0.0)
    if isinstance(result, dict):
        if entry:
            if result.get("ok") and result.get("done") is not False:
                journal.mark_undone(entry)
        else:
            journal.record(name, args, result)
            result.pop("created", None)                  # a Claude non serve l'elenco delle entita'
            if name not in READ_TOOLS:
                schedule_checks(bridge, name, result)
    return result


def _log(bridge: GameBridge, name: str, args: dict, result: dict, seconds: float) -> None:
    try:
        log_action(bridge.data_folder, name, args, result, seconds)
    except OSError as e:                                 # il registro non deve fermare il lavoro
        print(f"  (registro azioni non scritto: {e})")


def schedule_checks(bridge: GameBridge, name: str, result: dict) -> None:
    """Le linee appena create vanno ricontrollate dopo 1-2 mesi di gioco (collaudo a distanza di tempo)."""
    ids = list(result.get("line_ids") or [])
    if result.get("line_id") is not None and result.get("line_id") not in ids:
        ids.append(result["line_id"])
    if ids and result.get("ok") is not False:
        try:
            Collaudo(bridge.data_folder).add(ids, bridge.state(), action=name)
        except (OSError, RuntimeError) as e:
            print(f"  [avviso] collaudo a distanza non programmato per {ids}: {e}")


def run_due_checks(bridge: GameBridge) -> str:
    """Collaudi scaduti: check_line sul gioco per ogni linea; ritorna il testo da aggiungere al messaggio
    dell'utente (vuoto se non c'e' niente). Gli errori di comunicazione rimandano il controllo al turno dopo."""
    col = Collaudo(bridge.data_folder)
    try:
        state = bridge.state()
        due = col.due(state)[:MAX_AUTO_CHECKS]
    except (OSError, RuntimeError):
        return ""
    if not due or state.get("speed") == 0:
        return ""
    results, done = {}, []
    for L in due:
        try:
            r = bridge.send([{"type": "check_line", "line_id": L}], timeout=60)
        except TimeoutError:
            break
        results[L] = r[0] if r else None
        done.append(L)
    if not done:
        return ""
    col.mark_done(done)
    report = format_report(results)
    print("\n  [Collaudo automatico dopo 2 mesi di gioco]\n" + report)
    return "\n\n[Collaudo automatico dopo 2 mesi di gioco]\n" + report


def ask_claude(client, messages: list, bridge: GameBridge) -> None:
    """Un turno dell'utente: chiama Claude, esegue i tool richiesti e ripete finche' Claude ha finito."""
    for _ in range(MAX_TOOL_ROUNDS):
        resp = client.messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            **cached_request(SYSTEM_PROMPT, TOOLS, messages),   # prompt caching: meno costi
        )
        messages.append({"role": "assistant", "content": resp.content})
        add_usage(resp)

        for block in resp.content:
            if block.type == "text" and block.text.strip():
                print(f"\nCapo Cantiere: {block.text.strip()}")

        if resp.stop_reason != "tool_use":
            print("  " + usage_line())
            tot = USAGE["input"] + USAGE["output"] + USAGE["cache_read"] + USAGE["cache_write"]
            if TOKEN_WARN and tot > TOKEN_WARN:
                print(f"  [avviso] la sessione ha superato {TOKEN_WARN} token: valuta /reset o una sessione nuova")
            return

        tool_results = []
        for block in resp.content:
            if block.type != "tool_use":
                continue
            args = block.input or {}
            print(f"  [tool] {block.name} {json.dumps(args, ensure_ascii=False)}")
            problems = validate_args(TOOLS_BY_NAME.get(block.name, {}), args)
            if block.name not in TOOLS_BY_NAME:
                problems = [f"tool sconosciuto: {block.name}"]
            if problems:                                 # argomenti sbagliati: non disturbo il gioco
                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps({"ok": False, "error": "argomenti non validi", "details": problems},
                                          ensure_ascii=False),
                    "is_error": True,
                })
                continue
            try:
                if block.name in LOCAL_TOOLS:
                    out = run_local_tool(block.name, args, bridge)
                else:
                    out = run_game_tool(block.name, args, bridge)
                is_error = isinstance(out, dict) and out.get("ok") is False and not out.get("cancelled")
            except Exception as e:                       # un errore non deve chiudere la console
                out, is_error = {"ok": False, "error": f"{type(e).__name__}: {e}"}, True
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": json.dumps(out, ensure_ascii=False),
                "is_error": is_error,
            })
        messages.append({"role": "user", "content": tool_results})

    print("\n(Troppi passaggi di tool per una sola richiesta: mi fermo qui.)")


def main() -> None:
    try:
        import anthropic
    except ImportError:
        print("Manca la libreria anthropic. Installa con:  pip install anthropic")
        sys.exit(1)
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("Variabile ANTHROPIC_API_KEY non impostata (vedi istruzioni in cima a main.py).")
        sys.exit(1)

    bridge = GameBridge()
    moved = bridge.archive_stale_actions()
    if moved:
        print(f"Spostati in 'vecchi' {len(moved)} file azioni rimasti da sessioni precedenti: {', '.join(moved)}")
    try:
        for msg in check_versions(bridge.state(), bridge.data_folder):
            print("Attenzione: " + msg)
    except (OSError, RuntimeError) as e:
        print(f"Attenzione: controllo delle versioni non riuscito: {e}")
    client = anthropic.Anthropic()
    messages: list = []

    age = bridge.state_age_seconds()
    print(f"Capo Cantiere pronto. Modello: {MODEL}. Cartella: {bridge.folder}")
    if age > 60:
        print(f"Attenzione: state.lua ha {age:.0f} s. La partita e' aperta con la mod attiva?")
    print("Scrivi una direttiva, oppure /stato, /ping, /reset, /esci.\n")

    while True:
        try:
            text = input("Tu: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not text:
            continue
        if text in ("/esci", "/exit", "/quit"):
            print(usage_line())
            break
        if text == "/reset":
            messages = []
            print("Conversazione azzerata.")
            continue
        if text == "/ping":
            print("La mod risponde." if bridge.ping() else "Nessuna risposta dalla mod.")
            continue
        if text == "/stato":
            ov = overview(bridge.state())
            print(f"Anno {ov['year']}, soldi: {'illimitati' if ov['noCosts'] else ov['money']}")
            print(f"{len(ov['towns'])} citta': " + ", ".join(t['name'] for t in ov['towns']))
            print(f"{len(ov['industries'])} industrie, {len(ov['playerStations'])} tue stazioni, "
                  f"{len(ov['lines'])} linee")
            continue

        try:                                             # i turni vecchi diventano un riassunto
            summarize_history(client, MODEL, messages, MAX_TURNS - 1)
        except Exception as e:                           # se il riassunto non riesce, li taglio e basta
            print(f"(riassunto non riuscito: {type(e).__name__}; tengo solo gli ultimi turni)")
            trim_history(messages, MAX_TURNS - 1)
        if USE_BOZZA:
            text += run_due_checks(bridge)
        n_before = len(messages)
        messages.append({"role": "user", "content": text})
        try:
            ask_claude(client, messages, bridge)
        except anthropic.APIError as e:
            print(f"Errore API Anthropic: {e}")
            del messages[n_before:]                 # tolgo il turno non completato
        print()


if __name__ == "__main__":
    main()

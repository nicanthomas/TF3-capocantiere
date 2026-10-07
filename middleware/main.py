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
"""

from __future__ import annotations

import json
import os
import sys

from game_bridge import GameBridge, find_entities, overview
from tools import LOCAL_TOOLS, SPENDING_TOOLS, TOOLS, describe_action

# Modello Anthropic: cambia qui per usarne un altro (es. "claude-opus-5-5").
MODEL = "claude-sonnet-5-5"
MAX_TOKENS = 4096
MAX_TOOL_ROUNDS = 12           # limite di sicurezza ai giri di tool per una singola richiesta

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


def run_local_tool(name: str, args: dict, bridge: GameBridge) -> dict:
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
    if name in SPENDING_TOOLS:
        if not confirm(describe_action(name, args, bridge.state())):
            return {"ok": False, "cancelled": True, "message": "Annullato dall'utente."}
    action = {"type": name}
    action.update(args)
    print("  (in costruzione: puo' richiedere fino a qualche minuto...)")
    try:
        results = bridge.send([action], timeout=330)   # la mod aspetta fino a 300 s
    except TimeoutError as e:
        return {"ok": False, "error": str(e)}
    return results[0] if results else {"ok": False, "error": "nessun risultato"}


def ask_claude(client, messages: list, bridge: GameBridge) -> None:
    """Un turno dell'utente: chiama Claude, esegue i tool richiesti e ripete finche' Claude ha finito."""
    for _ in range(MAX_TOOL_ROUNDS):
        resp = client.messages.create(
            model=MODEL,
            max_tokens=MAX_TOKENS,
            system=SYSTEM_PROMPT,
            tools=TOOLS,
            messages=messages,
        )
        messages.append({"role": "assistant", "content": resp.content})

        for block in resp.content:
            if block.type == "text" and block.text.strip():
                print(f"\nCapo Cantiere: {block.text.strip()}")

        if resp.stop_reason != "tool_use":
            return

        tool_results = []
        for block in resp.content:
            if block.type != "tool_use":
                continue
            args = block.input or {}
            print(f"  [tool] {block.name} {json.dumps(args, ensure_ascii=False)}")
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

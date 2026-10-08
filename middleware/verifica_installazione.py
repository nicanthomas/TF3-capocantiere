"""
Controlla che tutto sia pronto per usare Capo Cantiere. Non modifica nulla.

    python verifica_installazione.py

Controlla: versione di Python, file del middleware, libreria anthropic, chiave API (solo se e' impostata: non
viene mai mostrata), cartella di scambio, state.lua aggiornato dalla mod (versione della mod, pausa), file azioni
rimasti da sessioni precedenti.
"""

from __future__ import annotations

import os
import re
import sys
import time

OK, WARN, ERR = "OK   ", "ATTENZIONE", "ERRORE"
problems = 0


def report(level: str, msg: str) -> None:
    global problems
    if level == ERR:
        problems += 1
    print(f"[{level}] {msg}")


def main() -> int:
    # Python
    v = sys.version_info
    if v >= (3, 10):
        report(OK, f"Python {v.major}.{v.minor}")
    else:
        report(ERR, f"Python {v.major}.{v.minor}: serve 3.10 o piu' recente")

    # file del middleware (un file mancante = installazione a meta')
    here = os.path.dirname(os.path.abspath(__file__))
    needed = ["main.py", "game_bridge.py", "tools.py", "tools_bozza.py", "lua_table.py", "conversation.py", "journal.py",
              "action_log.py", "collaudo.py", "versione.py"]
    missing = [f for f in needed if not os.path.exists(os.path.join(here, f))]
    if missing:
        report(ERR, "file del middleware mancanti: " + ", ".join(missing))
    else:
        report(OK, f"file del middleware: {len(needed)} presenti")

    # libreria anthropic
    try:
        import anthropic  # noqa: F401
        report(OK, f"libreria anthropic {getattr(anthropic, '__version__', '?')}")
    except ImportError:
        report(ERR, "libreria anthropic mancante: esegui  pip install anthropic")

    # chiave API: solo presenza e forma, mai il valore
    key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not key:
        report(ERR, "variabile ANTHROPIC_API_KEY non impostata: setx ANTHROPIC_API_KEY \"...\" e riapri il terminale")
    elif not key.startswith("sk-ant-"):
        report(WARN, "ANTHROPIC_API_KEY impostata ma non sembra una chiave Anthropic (non inizia con sk-ant-)")
    else:
        report(OK, "ANTHROPIC_API_KEY impostata")

    # cartella di scambio
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from game_bridge import DEFAULT_DIR, prefix_for
    folder = os.environ.get("CAPOCANTIERE_DIR", DEFAULT_DIR)
    if not os.path.isdir(folder):
        report(ERR, f"cartella di scambio non trovata: {folder} (imposta CAPOCANTIERE_DIR)")
        return finish()
    report(OK, f"cartella di scambio: {folder}")
    pre = prefix_for(folder)

    # state.lua
    st = os.path.join(folder, pre + "state.lua")
    if not os.path.exists(st):
        report(WARN, "state.lua non c'e' ancora: apri una partita con la mod Capo Cantiere attiva")
    else:
        age = time.time() - os.path.getmtime(st)
        if age < 60:
            report(OK, f"state.lua aggiornato {age:.0f} s fa: la mod e' attiva")
        else:
            report(WARN, f"state.lua vecchio di {age / 60:.0f} min: la partita e' aperta (non nel menu) con la mod attiva?")
        try:
            import lua_table
            s = lua_table.load_userdata(st)
            ver = s.get("modVersion")
            if ver:
                report(OK, f"versione della mod: {ver}" + (f", build del gioco {s['gameBuild']}" if s.get("gameBuild") else ""))
            else:
                report(WARN, "la mod non riporta la versione (v13 o precedente): le azioni della bozza non ci sono")
            if s.get("speed") == 0:
                report(WARN, "la partita e' in pausa: le azioni aspettano finche' non riprende")
        except Exception as e:                       # state.lua in scrittura o illeggibile: non e' grave
            report(WARN, f"state.lua non leggibile adesso ({type(e).__name__}): riprova tra qualche secondo")

    # file azioni rimasti
    stale = [f for f in os.listdir(folder) if re.fullmatch(re.escape(pre) + r"actions_\d+(_[0-9a-f]+)?\.lua", f)]
    if stale:
        report(WARN, f"file azioni rimasti: {', '.join(sorted(stale))} - main.py li sposta in '" + pre + "vecchi' all'avvio")
    return finish()


def finish() -> int:
    print()
    print("Tutto pronto." if problems == 0 else f"{problems} problema/i da risolvere prima di avviare main.py.")
    return 1 if problems else 0


if __name__ == "__main__":
    code = main()
    if os.name == "nt" and "--no-pause" not in sys.argv:
        input("Premi Invio per chiudere...")
    sys.exit(code)

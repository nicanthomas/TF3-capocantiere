"""
Prepara i file azione per provare codice nel gioco con sim_eval (solo con DEV_MODE = true nella mod).

    python dev-notes/mkeval.py --id 245 --key prova1 dev-notes/prove/p2_bus_intercity.lua
    python dev-notes/mkeval.py --id 245 --key sonda1 --solo-lib dev-notes/sonde/s1_api.lua

Crea due file nella cartella --out (default: la cartella di scambio, variabile CAPOCANTIERE_DIR):
  actions_<id>_<nonce>.lua     sim_eval con  cc_lib + cc_actions + bozza (b*.lua) + i file indicati
  actions_<id+1>_<nonce>.lua   sim_result della stessa chiave (legge il risultato al giro dopo)
L'id deve essere lastActionId + 1 (vedi state.lua): gli id saltati bloccano le azioni successive.
Opzioni: --solo-lib (senza cc_actions e bozza), --no-bozza (senza la bozza).
"""

from __future__ import annotations

import argparse
import glob
import os
import secrets
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "middleware"))
import lua_table  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", type=int, required=True)
    ap.add_argument("--key", required=True)
    ap.add_argument("--out", default=os.environ.get("CAPOCANTIERE_DIR", "."))
    ap.add_argument("--solo-lib", action="store_true")
    ap.add_argument("--no-bozza", action="store_true")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()

    parts = [os.path.join(HERE, "cc_lib.lua")]
    if not a.solo_lib:
        parts.append(os.path.join(HERE, "cc_actions.lua"))
        if not a.no_bozza:
            parts += sorted(glob.glob(os.path.join(HERE, "bozza", "b[0-9]_*.lua")))
    parts += a.files
    code = "\n".join(open(p, encoding="utf-8").read() for p in parts)

    names = []
    for i, action in ((a.id, {"type": "sim_eval", "key": a.key, "code": code}),
                      (a.id + 1, {"type": "sim_result", "key": a.key})):
        nonce = secrets.token_hex(4)
        name = f"actions_{i}_{nonce}"
        lua_table.save_userdata(os.path.join(a.out, name + ".lua"), {"id": i, "nonce": nonce, "actions": [action]})
        names.append(name)
    print(" ".join(names))
    print(f"({len(code)} caratteri di codice; prossimo id libero: {a.id + 2})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

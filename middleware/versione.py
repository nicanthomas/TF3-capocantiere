"""
Controllo delle versioni all'avvio: versione della mod (scritta da dev-notes/build_script.py) e build di Transport Fever 3
(se la mod riesce a leggerla). Se la build del gioco cambia, l'API potrebbe essere cambiata: avviso di rifare le prove.
Ultime versioni viste in <cartella capocantiere>/versioni_viste.json.
"""

from __future__ import annotations

import json
import os


def check_versions(state: dict, folder: str) -> list[str]:
    path = os.path.join(folder, "versioni_viste.json")
    try:
        with open(path, encoding="utf-8") as f:
            prev = json.load(f)
    except (OSError, ValueError):
        prev = {}
    cur = {"modVersion": state.get("modVersion"), "gameBuild": state.get("gameBuild")}
    msgs = []
    if not cur["modVersion"]:
        msgs.append("La mod non riporta la sua versione (v13 o precedente): alcune funzioni nuove non ci sono.")
    if prev.get("gameBuild") and cur["gameBuild"] and prev["gameBuild"] != cur["gameBuild"]:
        msgs.append(f"La build di Transport Fever 3 e' cambiata ({prev['gameBuild']} -> {cur['gameBuild']}): l'API potrebbe "
                    "essere cambiata. Prima di costruire esegui le prove (dev-notes/prove) sulla partita di test.")
    if prev.get("modVersion") and cur["modVersion"] and prev["modVersion"] != cur["modVersion"]:
        msgs.append(f"Mod aggiornata: {prev['modVersion']} -> {cur['modVersion']}.")
    if cur != {k: prev.get(k) for k in cur}:
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(cur, f, ensure_ascii=False)
        except OSError:
            pass
    return msgs

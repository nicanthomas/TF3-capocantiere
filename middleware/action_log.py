"""
Registro delle azioni mandate al gioco: una riga JSON per azione in <cartella capocantiere>/log/azioni_AAAA-MM.jsonl
(ora, azione, argomenti, esito, errore, durata, id creati, problemi del collaudo). Serve a capire cosa e' stato
tentato e perche' e' fallito, anche dopo giorni.
"""

from __future__ import annotations

import json
import os
import time

KEEP = ("line_id", "line_ids", "station_id", "stations", "depot_id", "trains", "vehicles", "warning", "cleanup",
        "cancelled", "notes", "alternatives")


def summarize_result(result: dict) -> dict:
    out = {k: result[k] for k in KEEP if isinstance(result, dict) and k in result}
    col = result.get("collaudo") if isinstance(result, dict) else None
    if isinstance(col, list):
        out["collaudo"] = [{"line_id": c.get("line_id"), "ok": c.get("ok"), "problems": c.get("problems", [])} for c in col]
    return out


def log_action(folder: str, name: str, args: dict, result: dict, seconds: float, when: float | None = None) -> str:
    """Aggiunge una riga al registro del mese e ritorna il percorso del file. Non solleva eccezioni sui dati."""
    when = when or time.time()
    d = os.path.join(folder, "log")
    os.makedirs(d, exist_ok=True)
    path = os.path.join(d, time.strftime("azioni_%Y-%m.jsonl", time.localtime(when)))
    entry = {
        "time": time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(when)),
        "action": name,
        "args": args,
        "ok": result.get("ok") if isinstance(result, dict) else None,
        "error": result.get("error") if isinstance(result, dict) else None,
        "seconds": round(seconds, 1),
        "result": summarize_result(result) if isinstance(result, dict) else str(result)[:300],
    }
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, default=str) + "\n")
    return path

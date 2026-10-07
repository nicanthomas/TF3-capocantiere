"""
Registro delle azioni che hanno costruito qualcosa (per "annulla l'ultima azione").

La mod (con la bozza) restituisce in ogni risultato `created` = { vehicles, lines, constructions, tracks, roads }.
Qui lo salvo in <cartella di scambio>/journal.json (ultime 30 azioni). L'annullamento manda alla mod
l'azione {type = "undo", created = ...} dell'ultima voce non ancora annullata.
"""

from __future__ import annotations

import json
import os
import time

MAX_ENTRIES = 30
UNDOABLE_KEYS = ("vehicles", "lines", "constructions", "tracks")


def _has_content(created) -> bool:
    return isinstance(created, dict) and any(created.get(k) for k in UNDOABLE_KEYS)


class Journal:
    def __init__(self, folder: str):
        self.path = os.path.join(folder, "journal.json")

    def load(self) -> list:
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
            return data if isinstance(data, list) else []
        except (OSError, ValueError):
            return []

    def _save(self, entries: list) -> None:
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(entries[-MAX_ENTRIES:], f, ensure_ascii=False, indent=1)
        os.replace(tmp, self.path)

    def record(self, action_type: str, args: dict, result: dict) -> bool:
        """Salva la voce se l'azione ha creato qualcosa di annullabile. Ritorna True se salvata."""
        created = result.get("created") if isinstance(result, dict) else None
        if not _has_content(created):
            return False
        entries = self.load()
        n = (entries[-1].get("n", 0) + 1) if entries else 1
        entries.append({"n": n, "time": time.strftime("%Y-%m-%d %H:%M:%S"), "type": action_type, "args": args,
                        "created": {k: created.get(k) or [] for k in UNDOABLE_KEYS + ("roads",)}, "undone": False})
        self._save(entries)
        return True

    def last_undoable(self) -> dict | None:
        for e in reversed(self.load()):
            if not e.get("undone") and _has_content(e.get("created")):
                return e
        return None

    def mark_undone(self, entry: dict) -> None:
        entries = self.load()
        for e in entries:
            if e.get("n") == entry.get("n") and not e.get("undone"):
                e["undone"] = True
                break
        self._save(entries)

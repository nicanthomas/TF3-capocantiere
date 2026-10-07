"""
Collaudo a distanza di tempo: le linee costruite vengono ricontrollate dopo DUE_MONTHS mesi di gioco (passeggeri e
merci trasportati, veicoli fermi, percorsi). Elenco in <cartella capocantiere>/collaudo.json.

Il tempo di gioco viene da state.lua: "date" = { year, month, day } se la mod lo esporta (v14), altrimenti
"gameTime" (unita' DA VERIFICARE: GAME_TIME_PER_MONTH resta None finche' non e' misurato in gioco), altrimenti
ripiego sul tempo reale (WALL_FALLBACK_S).
"""

from __future__ import annotations

import json
import os
import time

DUE_MONTHS = 2
GAME_TIME_PER_MONTH: float | None = None      # DA VERIFICARE in gioco (sonda s11)
WALL_FALLBACK_S = 20 * 60
MAX_ENTRIES = 200


def months_between(a: dict | None, b: dict | None) -> int | None:
    try:
        return (int(b["year"]) * 12 + int(b["month"])) - (int(a["year"]) * 12 + int(a["month"]))
    except (TypeError, KeyError, ValueError):
        return None


class Collaudo:
    def __init__(self, folder: str):
        self.path = os.path.join(folder, "collaudo.json")

    def _load(self) -> list:
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
            return data if isinstance(data, list) else []
        except (OSError, ValueError):
            return []

    def _save(self, entries: list) -> None:
        with open(self.path, "w", encoding="utf-8") as f:
            json.dump(entries[-MAX_ENTRIES:], f, ensure_ascii=False, indent=1)

    def add(self, line_ids: list, state: dict, action: str = "", now: float | None = None) -> int:
        """Programma il collaudo delle linee indicate. Ritorna quante ne ha aggiunte (le gia' in attesa no)."""
        entries = self._load()
        waiting = {e["line_id"] for e in entries if not e.get("done")}
        n = 0
        for L in line_ids:
            if L is None or L in waiting:
                continue
            entries.append({"line_id": L, "action": action, "date": state.get("date"), "gameTime": state.get("gameTime"),
                            "wall": now or time.time(), "done": False})
            n += 1
        if n:
            self._save(entries)
        return n

    def _is_due(self, e: dict, state: dict, now: float) -> bool:
        m = months_between(e.get("date"), state.get("date"))
        if m is not None:
            return m >= DUE_MONTHS
        g0, g1 = e.get("gameTime"), state.get("gameTime")
        if GAME_TIME_PER_MONTH and isinstance(g0, (int, float)) and isinstance(g1, (int, float)):
            return (g1 - g0) >= DUE_MONTHS * GAME_TIME_PER_MONTH
        return now - float(e.get("wall") or now) >= WALL_FALLBACK_S

    def due(self, state: dict, now: float | None = None) -> list[int]:
        now = now or time.time()
        return [e["line_id"] for e in self._load() if not e.get("done") and self._is_due(e, state, now)]

    def mark_done(self, line_ids: list) -> None:
        entries = self._load()
        for e in entries:
            if e["line_id"] in line_ids and not e.get("done"):
                e["done"] = True
        self._save(entries)


def format_report(results: dict) -> str:
    """Testo per Claude e per l'utente: { line_id: risultato di check_line }."""
    lines = []
    for L, r in results.items():
        if not isinstance(r, dict):
            lines.append(f"- linea {L}: controllo non riuscito")
            continue
        name = r.get("name") or f"linea {L}"
        stats = r.get("stats") or {}
        st = ", ".join(f"{k}={v}" for k, v in stats.items()) if stats else "statistiche non disponibili"
        if r.get("ok"):
            lines.append(f"- {name} (id {L}): funziona; {st}")
        else:
            probs = "; ".join(r.get("problems") or ["problema non specificato"])
            sugg = "; ".join(r.get("suggestions") or [])
            lines.append(f"- {name} (id {L}): PROBLEMI: {probs}" + (f" | suggerimenti: {sugg}" if sugg else "") + f"; {st}")
    return "\n".join(lines)

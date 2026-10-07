"""
Ponte file tra il middleware Python e la mod Lua "Capo Cantiere" in Transport Fever 3.

Cartella di scambio: <dati utente TF3>/capocantiere
  state.lua    scritto dalla mod ogni ~10 s  (citta', industrie, stazioni, linee, depositi)
  actions_<N>_<nonce>.lua  scritto da qui     { id = N, nonce = "...", actions = { {type=...}, ... } }
  results_<N>_<nonce>.lua  scritto dalla mod  { id = N, nonce = "...", results = { ... }, finishedAt = ... }

Gli id sono progressivi (1, 2, 3...); il nonce e' casuale. La mod cerca ogni ~1 s un file
actions_<ultimo+1>_*, lo esegue, scrive results con lo stesso nome e cancella il file azioni.
Il nonce serve perche' il gioco tiene in memoria, per tutta la sessione, il contenuto dei file
userdata gia' letti: un nome di file non deve mai ripetersi. L'ultimo id eseguito e' in state.lua.
Funziona solo con la partita aperta (non in pausa nel menu principale).
"""

from __future__ import annotations

import math
import os
import re
import secrets
import time
from typing import Any

import lua_table

DEFAULT_DIR = r"C:\Program Files (x86)\Steam\userdata\888286537\3493540\local\capocantiere"


class GameBridge:
    def __init__(self, folder: str | None = None):
        self.folder = folder or os.environ.get("CAPOCANTIERE_DIR", DEFAULT_DIR)
        if not os.path.isdir(self.folder):
            raise FileNotFoundError(
                f"Cartella di scambio non trovata: {self.folder}\n"
                "Imposta la variabile d'ambiente CAPOCANTIERE_DIR con il percorso giusto.")
        self._state: dict | None = None
        self._state_mtime = 0.0

    # ------------------------------------------------------------------ percorsi
    def _path(self, name: str) -> str:
        return os.path.join(self.folder, name + ".lua")

    # ------------------------------------------------------------------ stato
    def state(self, refresh: bool = True) -> dict:
        """Ultimo state.lua esportato dalla mod (ricaricato solo se il file e' cambiato)."""
        p = self._path("state")
        if not os.path.exists(p):
            raise RuntimeError("state.lua non esiste ancora: apri una partita con la mod Capo Cantiere attiva.")
        mtime = os.path.getmtime(p)
        if self._state is None or (refresh and mtime != self._state_mtime):
            for _ in range(3):                      # il gioco potrebbe star scrivendo proprio ora
                try:
                    self._state = lua_table.load_userdata(p)
                    break
                except lua_table.LuaParseError:
                    time.sleep(0.3)
            self._state_mtime = mtime
        return self._state

    def state_age_seconds(self) -> float:
        p = self._path("state")
        return time.time() - os.path.getmtime(p) if os.path.exists(p) else math.inf

    # ------------------------------------------------------------------ azioni
    def _next_id(self) -> int:
        """Prossimo id = lastActionId della mod + 1.
        La mod riscrive state.lua subito dopo ogni richiesta, quindi il valore e' sempre fresco;
        dopo il caricamento di un altro salvataggio riparte dal valore salvato nella partita."""
        st = self.state()
        return int(st.get("lastActionId") or 0) + 1

    def send(self, actions: list[dict], timeout: float = 30.0) -> list[dict]:
        """Scrive actions_<id>.lua e aspetta results_<id>.lua. Ritorna la lista dei risultati."""
        req_id = self._next_id()
        nonce = secrets.token_hex(4)
        lua_table.save_userdata(self._path(f"actions_{req_id}_{nonce}"),
                                {"id": req_id, "nonce": nonce, "actions": actions})
        deadline = time.time() + timeout
        rp = self._path(f"results_{req_id}_{nonce}")
        while time.time() < deadline:
            time.sleep(0.5)
            if not os.path.exists(rp):
                continue
            try:
                res = lua_table.load_userdata(rp)
            except lua_table.LuaParseError:
                continue                            # file in scrittura, riprovo
            if isinstance(res, dict) and res.get("id") == req_id and res.get("nonce") == nonce:
                self._wait_state_id(req_id)
                self._cleanup(req_id)
                out = res.get("results") or []
                return out if isinstance(out, list) else list(out.values())
        raise TimeoutError(
            f"Nessuna risposta dal gioco in {timeout:.0f} s (richiesta {req_id}). "
            "La partita e' aperta (non in pausa nel menu) e la mod e' attiva?")

    def _wait_state_id(self, req_id: int, timeout: float = 5.0) -> None:
        """Aspetta che state.lua riporti lastActionId >= req_id (la mod lo riscrive subito)."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                if int(self.state().get("lastActionId") or 0) >= req_id:
                    return
            except (RuntimeError, lua_table.LuaParseError):
                pass
            time.sleep(0.3)

    def _cleanup(self, upto: int) -> None:
        """Cancella i file results gia' letti."""
        for fn in os.listdir(self.folder):
            m = re.fullmatch(r"results_(\d+)(_[0-9a-f]+)?\.lua", fn)
            if m and int(m.group(1)) <= upto:
                try:
                    os.remove(os.path.join(self.folder, fn))
                except OSError:
                    pass

    def archive_stale_actions(self) -> list[str]:
        """All'avvio: i file actions_* presenti vengono da sessioni precedenti (il middleware li scrive solo
        mentre aspetta una risposta). Se restassero, la mod potrebbe eseguirli dopo il caricamento di un
        salvataggio. Li sposto nella sottocartella 'vecchi' (non li cancello)."""
        moved = []
        old_dir = os.path.join(self.folder, "vecchi")
        for fn in sorted(os.listdir(self.folder)):
            if re.fullmatch(r"actions_\d+(_[0-9a-f]+)?\.lua", fn):
                os.makedirs(old_dir, exist_ok=True)
                dst = os.path.join(old_dir, fn)
                if os.path.exists(dst):
                    dst = os.path.join(old_dir, f"{time.strftime('%Y%m%d_%H%M%S')}_{fn}")
                os.replace(os.path.join(self.folder, fn), dst)
                moved.append(fn)
        return moved

    def ping(self) -> bool:
        try:
            r = self.send([{"type": "ping"}], timeout=8)
            return bool(r and r[0].get("ok"))
        except TimeoutError:
            return False


# ---------------------------------------------------------------------- ricerca entita'

def _norm(s: str) -> str:
    import unicodedata
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return " ".join(s.lower().split())


def _dist(a: dict | None, b: dict | None) -> float | None:
    if not a or not b:
        return None
    return math.hypot(a["x"] - b["x"], a["y"] - b["y"])


def find_entities(state: dict, query: str, kind: str = "any", limit: int = 8) -> list[dict]:
    """Cerca per nome (senza accenti/maiuscole) tra citta', industrie, stazioni, linee, depositi."""
    q = _norm(query)
    groups = {
        "town": state.get("towns", []),
        "industry": state.get("industries", []),
        "station": state.get("stations", []),
        "line": state.get("lines", []),
        "depot": state.get("depots", []),
    }
    hits = []
    for k, items in groups.items():
        if kind not in ("any", k):
            continue
        for it in items:
            name = _norm(it.get("name", ""))
            if not q:
                score = 1
            elif name == q:
                score = 100
            elif name.startswith(q):
                score = 80
            elif q in name:
                score = 60
            elif all(w in name for w in q.split()):
                score = 40
            else:
                continue
            hits.append((score, k, it))
    hits.sort(key=lambda h: (-h[0], h[2].get("name", "")))
    out = []
    for score, k, it in hits[:limit]:
        item = {"kind": k, "id": it["id"], "name": it.get("name")}
        for f in ("pos", "type", "inputs", "outputs", "town", "carriers", "player", "stops", "vehicles", "carrier"):
            if f in it:
                item[f] = it[f]
        out.append(item)
    return out


def overview(state: dict) -> dict:
    """Riassunto compatto della mappa da dare al modello."""
    towns = state.get("towns", [])

    def nearest_town(pos):
        best = None
        for t in towns:
            d = _dist(pos, t.get("pos"))
            if d is not None and (best is None or d < best[0]):
                best = (d, t)
        return (best[1]["name"], round(best[0])) if best else (None, None)

    inds = []
    for i in state.get("industries", []):
        tn, td = nearest_town(i.get("pos"))
        short = (i.get("type") or "").split("/")[-1].replace(".con", "")
        inds.append({"id": i["id"], "name": i.get("name"), "type": short,
                     "in": i.get("inputs", []), "out": i.get("outputs", []),
                     "pos": i.get("pos"), "nearTown": tn, "distM": td})
    return {
        "year": state.get("year"),
        "money": state.get("money"),
        "noCosts": state.get("noCosts", False),
        "townAcceptedCargo": state.get("townAcceptedCargo", []),
        "towns": [{"id": t["id"], "name": t.get("name"), "pos": t.get("pos")} for t in towns],
        "industries": inds,
        "playerStations": [{"id": s["id"], "name": s.get("name"), "carriers": s.get("carriers"), "pos": s.get("pos")}
                           for s in state.get("stations", []) if s.get("player")],
        "lines": [{"id": l["id"], "name": l.get("name"), "stops": len(l.get("stops", [])),
                   "vehicles": l.get("vehicles"), "modes": l.get("transportModes")}
                  for l in state.get("lines", [])],
        "playerDepots": [{"id": d["id"], "name": d.get("name"), "carrier": d.get("carrier"), "pos": d.get("pos")}
                         for d in state.get("depots", []) if d.get("player")],
    }

"""
Ponte file tra il middleware Python e la mod Lua "Capo Cantiere" in Transport Fever 3.

Cartella di scambio: <dati utente TF3>/mod_presets, file con il prefisso "capocantiere_" (dalla build 40420 del
gioco la mod puo' leggere/scrivere solo nelle cartelle del gioco; prima era <dati utente>/capocantiere senza prefisso)
  capocantiere_state.lua    scritto dalla mod ogni ~10 s  (citta', industrie, stazioni, linee, depositi)
  capocantiere_actions_<N>_<nonce>.lua  scritto da qui     { id = N, nonce = "...", actions = { {type=...}, ... } }
  capocantiere_results_<N>_<nonce>.lua  scritto dalla mod  { id = N, nonce = "...", results = { ... }, finishedAt = ... }

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

import glob as _glob

STEAM_USERDATA_GLOBS = [
    r"C:\Program Files (x86)\Steam\userdata\*\3493540\local\mod_presets",
    r"C:\Program Files\Steam\userdata\*\3493540\local\mod_presets",
]
FILE_PREFIX = "capocantiere_"
WITHDRAW_RECHECK = 2.0      # s: dopo aver ritirato una richiesta, ricontrollo che la mod non l'abbia presa


class GameTimeout(TimeoutError):
    """Tempo scaduto. status = "ritirata" (mai eseguita, si puo' riprovare) o "accettata" (non ripetere)."""

    def __init__(self, message: str, req_id: int, status: str):
        super().__init__(message)
        self.req_id, self.status = req_id, status


def prefix_for(folder: str) -> str:
    """Prefisso dei nomi file: "capocantiere_" in mod_presets (build 40420+), nessuno nella vecchia cartella
    'capocantiere'. CAPOCANTIERE_PREFIX lo forza."""
    env = os.environ.get("CAPOCANTIERE_PREFIX")
    if env is not None:
        return env
    return "" if os.path.basename(os.path.normpath(folder)).lower() == "capocantiere" else FILE_PREFIX


def find_default_dir() -> str:
    """Cartella di scambio nei dati utente di Steam (3493540 = Transport Fever 3), senza ID dell'account nel codice.
    Se ce n'e' piu' d'una (piu' account Steam) prende quella usata piu' di recente. Variabile CAPOCANTIERE_DIR per
    forzarne un'altra."""
    found = []
    for pattern in STEAM_USERDATA_GLOBS:
        found += [d for d in _glob.glob(pattern) if os.path.isdir(d)]
    if not found:
        return STEAM_USERDATA_GLOBS[0].replace("*", "<steam-id>")
    return max(found, key=os.path.getmtime)


DEFAULT_DIR = find_default_dir()


class GameBridge:
    def __init__(self, folder: str | None = None):
        self.folder = folder or os.environ.get("CAPOCANTIERE_DIR", DEFAULT_DIR)
        if not os.path.isdir(self.folder):
            raise FileNotFoundError(
                f"Cartella di scambio non trovata: {self.folder}\n"
                "Imposta la variabile d'ambiente CAPOCANTIERE_DIR con il percorso giusto.")
        self.prefix = prefix_for(self.folder)
        # dati del middleware (registro, diario, collaudi): restano nella cartella 'capocantiere' accanto, che il
        # middleware (Python) puo' usare liberamente; la mod non la vede piu' dalla 40420
        if self.prefix:
            self.data_folder = os.path.join(os.path.dirname(os.path.normpath(self.folder)), "capocantiere")
            os.makedirs(self.data_folder, exist_ok=True)
        else:
            self.data_folder = self.folder
        self._state: dict | None = None
        self._state_mtime = 0.0
        self.late: dict[int, str] = {}              # richieste accettate senza risultato: id -> nonce
        self.late_results: dict[int, list[dict]] = {}

    # ------------------------------------------------------------------ percorsi
    def _path(self, name: str) -> str:
        return os.path.join(self.folder, self.prefix + name + ".lua")

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
        """Scrive actions_<id>.lua e aspetta results_<id>.lua. Ritorna la lista dei risultati.

        Se il tempo scade solleva GameTimeout con lo stato della richiesta:
          - "ritirata": la mod non l'aveva presa; il file e' stato spostato in 'vecchi' e NON verra' eseguito
            (si puo' riprovare senza rischio di doppioni);
          - "accettata": la mod l'ha gia' presa (lastActionId >= id): l'azione e' stata eseguita o e' in corso
            nel lato simulazione. NON va ripetuta; il risultato, se arriva, si legge con take_late_results().
        """
        self._collect_late()
        req_id = self._next_id()
        self._withdraw(req_id)                      # un file vecchio con lo stesso id verrebbe scelto al posto di questo
        nonce = secrets.token_hex(4)
        ap = self._path(f"actions_{req_id}_{nonce}")
        lua_table.save_userdata(ap, {"id": req_id, "nonce": nonce, "actions": actions})
        deadline = time.time() + timeout
        rp = self._path(f"results_{req_id}_{nonce}")
        while time.time() < deadline:
            time.sleep(0.5)
            res = self._read_result(rp, req_id, nonce)
            if res is not None:
                self._wait_state_id(req_id)
                self._cleanup(req_id)
                return res
        # tempo scaduto: provo a ritirare la richiesta se la mod non l'ha ancora presa
        if not self._accepted(req_id) and self._withdraw(req_id, nonce):
            time.sleep(WITHDRAW_RECHECK)            # la mod potrebbe averla letta proprio mentre la spostavo
            if not self._accepted(req_id):
                raise GameTimeout(
                    f"Nessuna risposta dal gioco in {timeout:.0f} s (richiesta {req_id}): richiesta RITIRATA, "
                    "non e' stata eseguita. La partita e' aperta (non in pausa nel menu) e la mod e' attiva?",
                    req_id, "ritirata")
        res = self._read_result(rp, req_id, nonce)  # arrivata proprio ora?
        if res is not None:
            self._cleanup(req_id)
            return res
        self.late[req_id] = nonce
        raise GameTimeout(
            f"La mod ha accettato la richiesta {req_id} ma il risultato non e' arrivato in {timeout:.0f} s. "
            "NON ripeterla: potrebbe essere ancora in corso. Controlla lo stato del gioco prima di altre azioni.",
            req_id, "accettata")

    def _read_result(self, rp: str, req_id: int, nonce: str) -> list[dict] | None:
        if not os.path.exists(rp):
            return None
        try:
            res = lua_table.load_userdata(rp)
        except (lua_table.LuaParseError, OSError):
            return None                             # file in scrittura, riprovo
        if isinstance(res, dict) and res.get("id") == req_id and res.get("nonce") == nonce:
            out = res.get("results") or []
            return out if isinstance(out, list) else list(out.values())
        return None

    def _accepted(self, req_id: int) -> bool:
        """La mod segna l'id come eseguito (lastActionId) appena prende il file azioni."""
        try:
            return int(self.state().get("lastActionId") or 0) >= req_id
        except (RuntimeError, OSError, ValueError, lua_table.LuaParseError):
            return False

    def _withdraw(self, req_id: int, nonce: str | None = None) -> list[str]:
        """Sposta in 'vecchi' i file actions_<req_id>_* (o solo quello col nonce dato). Non cancella nulla."""
        pat = re.escape(self.prefix) + rf"actions_{req_id}_" + (re.escape(nonce) if nonce else r"[0-9a-f]+") + r"\.lua"
        moved = []
        for fn in sorted(os.listdir(self.folder)):
            if re.fullmatch(pat, fn):
                try:
                    self._move_old(fn)
                    moved.append(fn)
                except OSError:
                    pass                            # gia' preso dalla mod
        return moved

    def _move_old(self, fn: str) -> None:
        old_dir = os.path.join(self.folder, self.prefix + "vecchi")
        os.makedirs(old_dir, exist_ok=True)
        dst = os.path.join(old_dir, fn)
        if os.path.exists(dst):
            dst = os.path.join(old_dir, f"{time.strftime('%Y%m%d_%H%M%S')}_{fn}")
        os.replace(os.path.join(self.folder, fn), dst)

    def _collect_late(self) -> None:
        """Legge i risultati arrivati in ritardo per richieste accettate (prima che _cleanup li cancelli)."""
        for req_id, nonce in list(self.late.items()):
            res = self._read_result(self._path(f"results_{req_id}_{nonce}"), req_id, nonce)
            if res is not None:
                self.late_results[req_id] = res
                del self.late[req_id]

    def take_late_results(self) -> dict[int, list[dict]]:
        """Risultati arrivati dopo il timeout (id -> risultati); li consegna una volta sola."""
        self._collect_late()
        out, self.late_results = self.late_results, {}
        return out

    def _wait_state_id(self, req_id: int, timeout: float = 5.0) -> None:
        """Aspetta che state.lua riporti lastActionId >= req_id (la mod lo riscrive subito)."""
        deadline = time.time() + timeout
        last = None
        while time.time() < deadline:
            try:
                if int(self.state().get("lastActionId") or 0) >= req_id:
                    return
            except (RuntimeError, lua_table.LuaParseError) as e:
                last = e
            time.sleep(0.3)
        print(f"  [avviso] state.lua non conferma l'azione {req_id} dopo {timeout:.0f} s" + (f" ({last})" if last else ""))

    def _cleanup(self, upto: int) -> None:
        """Cancella i file results gia' letti."""
        for fn in os.listdir(self.folder):
            m = re.fullmatch(re.escape(self.prefix) + r"results_(\d+)(_[0-9a-f]+)?\.lua", fn)
            if m and int(m.group(1)) <= upto and int(m.group(1)) not in self.late:
                try:
                    os.remove(os.path.join(self.folder, fn))
                except OSError:
                    pass

    def archive_stale_actions(self) -> list[str]:
        """All'avvio: i file actions_* presenti vengono da sessioni precedenti (il middleware li scrive solo
        mentre aspetta una risposta). Se restassero, la mod potrebbe eseguirli dopo il caricamento di un
        salvataggio. Li sposto nella sottocartella 'vecchi' (non li cancello)."""
        moved = []
        for fn in sorted(os.listdir(self.folder)):
            if re.fullmatch(re.escape(self.prefix) + r"actions_\d+(_[0-9a-f]+)?\.lua", fn):
                self._move_old(fn)
                moved.append(fn)
        return moved

    def ping(self) -> bool:
        try:
            r = self.send([{"type": "ping"}], timeout=8)
            return bool(r and r[0].get("ok"))
        except TimeoutError:                       # anche GameTimeout
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

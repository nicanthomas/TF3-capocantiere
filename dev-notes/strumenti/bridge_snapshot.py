"""Riepilogo di un file stato esplicito: sola lettura, mai una prova del bridge vivo."""
import argparse
import json
import os
from pathlib import Path
import stat
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "middleware"))
import lua_table

MAX_STATE_BYTES = 8 * 1024 * 1024
SECTIONS = ("towns", "industries", "stations", "lines", "depots")


class SnapshotError(ValueError):
    pass


def signature(info):
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns


def read_snapshot(path):
    raw = os.fspath(path)
    if not isinstance(raw, str) or raw.startswith((chr(92)*2, "//")):
        raise SnapshotError("Richiesto percorso locale esplicito")
    path = Path(raw)
    if not path.is_absolute() or path.name not in ("state.lua", "capocantiere_state.lua"):
        raise SnapshotError("Richiesto percorso assoluto con nome file stato")
    if path.is_symlink():
        raise SnapshotError("Collegamento simbolico non accettato")
    initial = path.stat()
    if not stat.S_ISREG(initial.st_mode):
        raise SnapshotError("Richiesto file stato regolare")
    if initial.st_size > MAX_STATE_BYTES:
        raise SnapshotError("File stato oltre il limite diagnostico")
    with path.open("rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_size > MAX_STATE_BYTES:
            raise SnapshotError("File stato non regolare o oltre limite")
        content = stream.read(MAX_STATE_BYTES + 1)
        after = os.fstat(stream.fileno())
    if len(content) > MAX_STATE_BYTES:
        raise SnapshotError("File stato oltre il limite diagnostico")
    if signature(initial) != signature(before) or signature(before) != signature(after) or signature(after) != signature(path.stat()):
        raise SnapshotError("File stato cambiato durante la lettura")
    return content.decode("utf-8-sig")


def observe_state(path):
    out = {"ok": False, "read_only": True, "live_bridge_tested": False,
           "errors": [], "warnings": []}
    try:
        text = read_snapshot(path)
    except SnapshotError as exc:
        out["errors"].append(str(exc))
        return out
    except (OSError, TypeError, ValueError, UnicodeError):
        out["errors"].append("File stato non leggibile o codifica non valida")
        return out
    try:
        state = lua_table.loads(text)
    except (ValueError, TypeError, OverflowError, RecursionError):
        out["errors"].append("Contenuto stato non interpretabile")
        return out
    if not isinstance(state, dict):
        out["errors"].append("Stato non contiene una tabella con campi")
        return out
    action_id = state.get("lastActionId")
    out["last_action_id_valid"] = type(action_id) is int and action_id >= 0
    if not out["last_action_id_valid"]:
        out["errors"].append("lastActionId assente o non valido")
    out["mod_version_present"] = isinstance(state.get("modVersion"), str)
    out["counts"] = {}
    for name in SECTIONS:
        value = state.get(name)
        if name not in state:
            out["counts"][name] = None
            out["warnings"].append(name + ": sezione assente")
        elif isinstance(value, list):
            out["counts"][name] = len(value)
        else:
            out["counts"][name] = None
            out["errors"].append(name + ": tipo sezione non valido")
    if "errors" in state:
        if isinstance(state["errors"], list):
            out["export_errors_count"] = len(state["errors"])
            if state["errors"]:
                out["warnings"].append("Esportazione segnala errori; contenuti non esposti")
        else:
            out["errors"].append("errors: tipo sezione non valido")
    out["ok"] = not out["errors"]
    return out


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-file", required=True, help="File stato locale assoluto autorizzato")
    args = parser.parse_args(argv)
    result = observe_state(args.state_file)
    print(json.dumps(result, ensure_ascii=True))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

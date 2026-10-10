"""Suite Windows in venv con fixtures nuove e guardie audit Python.

Avviare con Python del venv, -I -B e --fixtures-root cartella artefatti
autorizzata. Non installa nulla, non usa dati del gioco o chiavi API.
Le guardie audit non sono un sandbox OS per codice nativo: eseguire solo
test del repository revisionati, mai codice o DLL non fidati.
"""
from pathlib import Path
import argparse
import glob
import json
import os
import sys
import tempfile
import unittest
import uuid


class IsolationError(RuntimeError):
    pass


def make_guard(root, writes):
    root = Path(root).resolve()

    def owned(path):
        resolved = Path(os.fsdecode(path)).resolve()
        return resolved == root or root in resolved.parents

    def steam(path):
        return isinstance(path, (str, bytes, os.PathLike)) and "steam" in os.fsdecode(path).lower()

    def guard(event, args):
        if event in ("socket.__new__", "socket.connect", "socket.bind", "socket.sendto",
                     "socket.sendmsg", "socket.getaddrinfo", "subprocess.Popen", "os.system",
                     "os.startfile", "os.startfile/2", "os.exec", "os.posix_spawn", "os.fork"):
            raise IsolationError("Rete o processo esterno bloccato nei test isolati")
        if event == "open":
            path, mode, flags = args
            if not isinstance(path, (str, bytes, os.PathLike)):
                return  # fdopen of a fixture descriptor previously audited.
            if steam(path):
                raise IsolationError("Lettura/scrittura Steam o gioco bloccata")
            writing = (isinstance(mode, str) and any(ch in mode for ch in "wax+")) or (
                isinstance(flags, int) and flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC))
            if writing:
                if not owned(path):
                    raise IsolationError("Scrittura fuori dalle fixtures bloccata")
                writes.add(str(Path(os.fsdecode(path)).resolve()))
        if event in ("os.mkdir", "os.remove", "os.rmdir", "os.rename"):
            paths = args[:2] if event == "os.rename" else args[:1]
            for path in paths:
                if isinstance(path, (str, bytes, os.PathLike)) and not owned(path):
                    raise IsolationError("Modifica filesystem fuori dalle fixtures bloccata")
        if event in ("os.listdir", "os.scandir", "ctypes.dlopen") and args and steam(args[0]):
            raise IsolationError("Accesso Steam o caricamento libreria gioco bloccato")
    return guard


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixtures-root", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        parser.error("Questo runner isolato e' per Windows; su Linux usare suite/CI con Lua reale")
    if sys.prefix == sys.base_prefix or not sys.flags.isolated or not sys.dont_write_bytecode:
        parser.error("Usare Python di un venv esistente con -I -B; nessuna dipendenza da installare")
    parent = args.fixtures_root.resolve()
    if "steam" in str(parent).lower():
        parser.error("Le fixtures devono stare fuori dalle directory Steam/gioco")
    parent.mkdir(parents=True, exist_ok=True)
    root = parent / ("fixtures-" + uuid.uuid4().hex)
    root.mkdir(exist_ok=False)
    tempfile.tempdir = str(root)
    os.environ["CAPOCANTIERE_DIR"] = str(root / "unused-exchange")
    os.environ["ANTHROPIC_API_KEY"] = ""  # Child process only: never read the real key.
    os.environ["CAPOCANTIERE_BOZZA"] = "0"
    os.environ["CAPOCANTIERE_REQUIRE_LUA"] = "0"
    repo = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(repo / "middleware"))
    original_glob = glob.glob

    def isolated_glob(pattern, *args, **kwargs):
        if "steam" in str(pattern).lower():
            return []
        return original_glob(pattern, *args, **kwargs)

    glob.glob = isolated_glob
    writes = set()
    sys.addaudithook(make_guard(root, writes))
    suite = unittest.defaultTestLoader.discover(str(repo / "middleware"), pattern="test_*.py")
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    print(json.dumps({"tests_run": result.testsRun, "failures": len(result.failures),
                      "errors": len(result.errors), "skips": len(result.skipped),
                      "skip_reasons": [reason for _, reason in result.skipped],
                      "success": result.wasSuccessful(), "fixture_write_targets": len(writes),
                      "venv": True, "python_audit_guards": True}, ensure_ascii=True))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main())

"""Controllo sintassi, senza esecuzione: python dev-notes/luachk.py FILE..."""
from pathlib import Path
import sys
from lua_runtime import LuaError, LuaUnavailable, run


def main(paths):
    failed = False
    for path in paths:
        try:
            run(Path(path).read_text(encoding="utf-8"), execute=False, name=path)
            print("OK", path)
        except (LuaError, LuaUnavailable, OSError) as exc:
            print("ERR", path, str(exc))
            failed = True
    return int(failed)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

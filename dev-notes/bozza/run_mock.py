"""Mock Lua isolato dal gioco: python dev-notes/bozza/run_mock.py."""
from pathlib import Path
import sys

HERE = Path(__file__).resolve().parent
DEV = HERE.parent
sys.path.insert(0, str(DEV))
from lua_runtime import LuaError, LuaUnavailable, run


def main():
    parts = [HERE / "test_mock_pre.lua", DEV / "cc_lib.lua", DEV / "cc_actions.lua"]
    parts += sorted(HERE.glob("b[0-9]_*.lua"))
    parts += [HERE / "test_mock_casi.lua"]
    code = "\n".join(path.read_text(encoding="utf-8") for path in parts)
    try:
        run(code, name="bozza")
    except (LuaError, LuaUnavailable) as exc:
        print("ERRORE:", exc, file=sys.stderr)
        return 1
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())

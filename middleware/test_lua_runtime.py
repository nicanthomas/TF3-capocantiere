"""Test del wrapper ctypes: ABI simulata, nessun runtime o gioco caricato."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes"))
import lua_runtime


class Function:
    def __init__(self, action):
        self.action = action
    def __call__(self, *args):
        return self.action(*args)


class Library:
    def __init__(self, load_error=0, call_error=0, state=123):
        self.closed = []
        self.executed = []
        self.sources = []
        self.luaL_newstate = Function(lambda: state)
        self.luaL_openlibs = Function(lambda state: None)
        self.luaL_loadbufferx = Function(self.load)
        self.lua_pcallk = Function(self.call)
        self.lua_tolstring = Function(lambda *args: b"test Lua error")
        self.lua_close = Function(lambda state: self.closed.append(state))
        self.load_error = load_error
        self.call_error = call_error
    def load(self, state, source, size, name, mode):
        self.sources.append((source, size, mode))
        return self.load_error
    def call(self, *args):
        self.executed.append(args)
        return self.call_error


class LuaRuntimeTests(unittest.TestCase):
    def test_missing_library_has_actionable_error(self):
        with patch.dict(lua_runtime.os.environ, {}, clear=True):
            with patch.object(lua_runtime, "find_library", return_value=None):
                with self.assertRaisesRegex(lua_runtime.LuaUnavailable, "CAPOCANTIERE_LUA_LIB"):
                    lua_runtime.load_library()

    def test_explicit_relative_library_rejected_before_loading(self):
        with patch.dict(lua_runtime.os.environ, {"CAPOCANTIERE_LUA_LIB": "lua54.dll"}):
            with self.assertRaisesRegex(lua_runtime.LuaUnavailable, "assoluto"):
                lua_runtime.load_library()

    def test_explicit_bad_library_does_not_fall_back(self):
        with patch.dict(lua_runtime.os.environ, {"CAPOCANTIERE_LUA_LIB": str(Path("trusted.dll").resolve())}):
            with patch.object(lua_runtime.ctypes, "CDLL", side_effect=OSError("bad architecture")):
                with self.assertRaisesRegex(lua_runtime.LuaUnavailable, "bad architecture"):
                    lua_runtime.load_library()

    def test_success_closes_state_and_uses_utf8_text(self):
        library = Library()
        lua_runtime.run("return 'citt\u00e0'", library=library)
        self.assertEqual(library.closed, [123])
        self.assertEqual(len(library.executed), 1)
        self.assertEqual(library.sources, [(b"return 'citt\xc3\xa0'", 15, b"t")])

    def test_syntax_error_never_executes_and_closes(self):
        library = Library(load_error=3)
        with self.assertRaisesRegex(lua_runtime.LuaError, "test Lua error"):
            lua_runtime.run("bad Lua", library=library)
        self.assertEqual(library.executed, [])
        self.assertEqual(library.closed, [123])

    def test_runtime_error_closes_state(self):
        library = Library(call_error=2)
        with self.assertRaises(lua_runtime.LuaError):
            lua_runtime.run("error('x')", library=library)
        self.assertEqual(library.closed, [123])

    def test_syntax_check_does_not_execute_code(self):
        library = Library()
        lua_runtime.run("os.exit()", execute=False, library=library)
        self.assertEqual(library.executed, [])
        self.assertEqual(library.closed, [123])

    def test_allocation_failure_does_not_use_null_state(self):
        library = Library(state=None)
        with self.assertRaises(MemoryError):
            lua_runtime.run("return 1", library=library)
        self.assertEqual(library.sources, [])
        self.assertEqual(library.closed, [])

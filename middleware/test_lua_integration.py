"""Runtime Lua reale quando disponibile; su Windows senza DLL skip esplicito."""
from pathlib import Path
import importlib.util
import os
import sys
import unittest
from unittest.mock import patch
DEV = Path(__file__).resolve().parents[1] / "dev-notes"
sys.path.insert(0, str(DEV))
import lua_runtime


class LuaIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            cls.library = lua_runtime.load_library()
        except lua_runtime.LuaUnavailable as exc:
            if os.environ.get("CAPOCANTIERE_REQUIRE_LUA") == "1":
                raise
            raise unittest.SkipTest(str(exc))

    def test_real_runtime_utf8(self):
        lua_runtime.run("assert('citt\u00e0' == string.char(99,105,116,116,195,160))", library=self.library)

    def test_real_syntax_error_is_raised(self):
        with self.assertRaises(lua_runtime.LuaError):
            lua_runtime.run("local =", execute=False, library=self.library)

    def test_real_runtime_error_is_raised(self):
        with self.assertRaisesRegex(lua_runtime.LuaError, "regressione"):
            lua_runtime.run("error('regressione')", library=self.library)

    def test_real_syntax_check_does_not_execute(self):
        lua_runtime.run("error('non eseguire')", execute=False, library=self.library)

    def test_mock_failed_check_returns_nonzero(self):
        spec = importlib.util.spec_from_file_location("isolated_run_mock", DEV / "bozza/run_mock.py")
        runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(runner)
        read = Path.read_text
        def inject_failed_check(path, *args, **kwargs):
            source = read(path, *args, **kwargs)
            if path.name == "test_mock_casi.lua":
                source = source.replace('print(string.format("RISULTATO:', 'check(false, "regressione intenzionale")\nprint(string.format("RISULTATO:', 1)
            return source
        # Actual Lua executes the complete fake-game fixture; only input text
        # is patched, never real files. No mock of run() or error handling.
        with patch.object(Path, "read_text", inject_failed_check):
            self.assertEqual(runner.main(), 1)

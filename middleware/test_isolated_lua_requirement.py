"""Bootstrap isolato e policy Lua reale: libreria simulata, niente DLL/gioco/chiavi."""
import contextlib
import glob
import io
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "dev-notes/strumenti"))
import test_isolati
import test_lua_integration as integration


class IsolatedLuaRequirementTests(unittest.TestCase):
    def run_probe(self, required, available):
        # Exercise the actual integration setUpClass availability policy; never load Lua.
        library = object()
        class NativeProbe(unittest.TestCase):
            @classmethod
            def setUpClass(cls):
                integration.LuaIntegrationTests.setUpClass.__func__(cls)
            def test_ready(self):
                self.assertIs(self.library, library)
        env = {"CAPOCANTIERE_REQUIRE_LUA": "1"}  # Default must still explicitly allow skip.
        fake_os = SimpleNamespace(name="nt", environ=env)
        fake_sys = SimpleNamespace(prefix="venv", base_prefix="base",
            flags=SimpleNamespace(isolated=True), dont_write_bytecode=True,
            path=sys.path[:], addaudithook=lambda hook: None)
        with tempfile.TemporaryDirectory() as folder:
            argv = ["test_isolati.py", "--fixtures-root", folder]
            if required:
                argv.append("--require-lua")
            fake_sys.argv = argv
            output, errors = io.StringIO(), io.StringIO()
            with contextlib.ExitStack() as stack:
                stack.enter_context(patch.object(sys, "argv", argv))
                stack.enter_context(patch.object(test_isolati, "sys", fake_sys))
                stack.enter_context(patch.object(test_isolati, "os", fake_os))
                stack.enter_context(patch.object(integration, "os", SimpleNamespace(environ=env)))
                stack.enter_context(patch.object(tempfile, "tempdir", tempfile.tempdir))
                stack.enter_context(patch.object(glob, "glob", glob.glob))
                stack.enter_context(patch.object(unittest.defaultTestLoader, "discover",
                    return_value=unittest.defaultTestLoader.loadTestsFromTestCase(NativeProbe)))
                loader = stack.enter_context(patch.object(integration.lua_runtime, "load_library"))
                if available:
                    loader.return_value = library
                else:
                    loader.side_effect = integration.lua_runtime.LuaUnavailable("runtime simulato assente")
                stack.enter_context(contextlib.redirect_stdout(output))
                stack.enter_context(contextlib.redirect_stderr(errors))
                code = test_isolati.main()
            result = json.loads(output.getvalue())
        return code, result

    def test_default_missing_runtime_remains_explicit_skip(self):
        code, result = self.run_probe(False, False)
        self.assertEqual(code, 0)
        self.assertEqual((result["errors"], result["skips"]), (0, 1))
        self.assertFalse(result["lua_required"])
        self.assertTrue(result["success"])

    def test_required_missing_runtime_fails_instead_of_skip(self):
        code, result = self.run_probe(True, False)
        self.assertNotEqual(code, 0)
        self.assertEqual((result["errors"], result["skips"]), (1, 0))
        self.assertTrue(result["lua_required"])
        self.assertFalse(result["success"])

    def test_required_available_runtime_reaches_test(self):
        code, result = self.run_probe(True, True)
        self.assertEqual(code, 0)
        self.assertEqual((result["tests_run"], result["errors"], result["skips"]), (1, 0, 0))
        self.assertTrue(result["lua_required"])
        self.assertTrue(result["success"])

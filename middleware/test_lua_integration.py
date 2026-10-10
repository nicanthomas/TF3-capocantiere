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

    def fleet_check(self, assertion):
        parts = [DEV / "bozza/test_mock_pre.lua", DEV / "cc_lib.lua", DEV / "cc_actions.lua"]
        parts += sorted((DEV / "bozza").glob("b[0-9]_*.lua"))
        source = "\n".join(path.read_text(encoding="utf-8") for path in parts)
        lua_runtime.run(source + "\n" + assertion, library=self.library, name="flotta-regressione")

    def test_fleet_clamped_count_matches_details(self):
        self.fleet_check("""
            local n, info = CC.initialFleet({1, 2}, nil, "bus", 7, 6)
            assert(n == 6 and info.count == 6 and not info.estimated, "dettagli count diversi dalla flotta limitata")
        """)

    def test_fleet_missing_positions_respect_limit(self):
        self.fleet_check("""
            CC.posOf = function() return nil end
            local n, info = CC.initialFleet({1, 2}, nil, "train", nil, 1)
            assert(n == 1 and info.count == 1 and not info.estimated and info.error, "fallback supera hardMax")
        """)

    def test_fleet_missing_middle_position_does_not_estimate_partial_route(self):
        self.fleet_check("""
            CC.posOf = function(id) if id ~= 2 then return { x = id * 1000, y = 0 } end end
            local n, info = CC.initialFleet({1, 2, 3, 4}, nil, "bus", nil, 6)
            assert(n == 2 and info.count == 2 and not info.estimated and info.error, "posizione mancante ignorata")
        """)

    def test_cargo_quality_uses_explicit_fields_on_real_lua_userdata(self):
        self.fleet_check("""
            local obj = io.stdout
            local original = debug.getmetatable(obj)
            local reads = 0
            debug.setmetatable(obj, {
                __index = function(_, key)
                    reads = reads + 1
                    if key == "countBad" then return 0 end
                    if key == "countTotal" then return 1 end
                    if key == "isVeryBad" then return false end
                    if key == "averageQuality" then return nil end
                    error("campo non dichiarato")
                end,
                __pairs = function() error("non enumerare userdata") end,
                __tostring = function() error("non convertire userdata") end
            })
            local ok, result = pcall(function()
                return CC.normalizeCargoQuality({passengers=obj, cargo=obj})
            end)
            debug.setmetatable(obj, original)
            assert(ok, "normalizzazione userdata non riuscita")
            assert(reads == 8 and result.available and result.passengers.available
                and result.cargo.available and result.passengers.isVeryBad == false
                and result.cargo.averageQuality == nil,
                "campi userdata espliciti o valore false persi")
        """)

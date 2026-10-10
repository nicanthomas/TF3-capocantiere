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

    def test_fleet_invalid_intervals_rejected_before_world_reads(self):
        self.fleet_check("""
            local reads, sent = 0, #W.sent
            CC.lineVehicles = function() reads = reads + 1; error("unexpected-world-read") end
            for _, value in ipairs({0, -1, 59, 3601, math.huge, -math.huge, 0/0}) do
                for _, apply in ipairs({false, true}) do
                    local ok, result = pcall(SIM_ACTIONS.adjust_line_fleet,
                        {line_id=1, interval=value, apply=apply})
                    local message = ok and type(result) == "table" and result.error or result
                    assert(type(message) == "string" and message:find("interval", 1, true)
                        and reads == 0 and #W.sent == sent, "interval non rifiutato prima della lettura")
                end
            end
        """)

    def test_fleet_invalid_caps_rejected_before_world_reads(self):
        self.fleet_check("""
            local reads, sent = 0, #W.sent
            CC.lineVehicles = function() reads = reads + 1; error("unexpected-world-read") end
            for _, value in ipairs({0, -1, 21, math.huge, -math.huge, 0/0, 1.5}) do
                for _, apply in ipairs({false, true}) do
                    local ok, result = pcall(SIM_ACTIONS.adjust_line_fleet,
                        {line_id=1, max=value, apply=apply})
                    local message = ok and type(result) == "table" and result.error or result
                    assert(type(message) == "string" and message:find("max", 1, true)
                        and reads == 0 and #W.sent == sent, "max non rifiutato prima della lettura")
                end
            end
        """)

    def test_fleet_nonfinite_measurements_never_propose_or_apply(self):
        self.fleet_check("""
            local times, attempts = {}, 0
            local originalComp = CC.comp
            CC.lineVehicles = function() return {101, 102} end
            CC.lineGroups = function() return {1, 2} end
            CC.comp = function(id, kind)
                if id == 101 or id == 102 then return {sectionTimes=times[id]} end
                return originalComp(id, kind)
            end
            CC.vehicleModels = function() return {501} end
            CC.modelFolder = function() return "bus" end
            CC.lineCargoQuality = function() return {available=false, errors={}} end
            SIM_ACTIONS.add_vehicles = function() attempts=attempts+1; return {ok=true} end
            SIM_ACTIONS.remove_vehicles = function() attempts=attempts+1; return {ok=true} end
            local cases = {
                {[101]={math.huge, 180}, [102]={math.huge, 180}},
                {[101]={1e308, 180}, [102]={1e308, 180}},
                {[101]={1e308, 1e308}, [102]={}}
            }
            for _, sample in ipairs(cases) do
                times=sample
                for _, apply in ipairs({false, true}) do
                    local out=SIM_ACTIONS.adjust_line_fleet({line_id=1, apply=apply})
                    assert(not out.ok and out.error:find("non ancora misurati", 1, true)
                        and out.round_trip_s == nil and out.interval_now_s == nil
                        and out.target == nil and out.proposal == nil and attempts == 0,
                        "misura non finita genera stima o tentativo di modifica")
                end
            end
        """)

    def test_fleet_large_integer_times_do_not_wrap_or_sell(self):
        self.fleet_check("""
            local adds, removes = 0, 0
            local originalComp = CC.comp
            CC.lineVehicles=function() return {101,102} end
            CC.lineGroups=function() return {1,2} end
            CC.comp=function(id,kind)
                if id == 101 or id == 102 then return {sectionTimes={math.maxinteger,math.maxinteger}} end
                return originalComp(id,kind)
            end
            CC.vehicleModels=function() return {501} end
            CC.modelFolder=function() return "bus" end
            CC.lineCargoQuality=function() return {available=false,errors={}} end
            SIM_ACTIONS.add_vehicles=function(a) adds=adds+1; assert(a.count==18); return {ok=true} end
            SIM_ACTIONS.remove_vehicles=function() removes=removes+1; return {ok=true} end
            for _,apply in ipairs({false,true}) do
                local out=SIM_ACTIONS.adjust_line_fleet({line_id=1,apply=apply})
                assert(out.ok and out.round_trip_s == (math.maxinteger+0.0)*2
                    and out.round_trip_s > 0 and out.round_trip_s < math.huge
                    and out.target==20 and out.change==18 and removes==0,
                    "overflow intero altera il giro o vende veicoli")
            end
            assert(adds==1 and removes==0, "applicazione fixture non coerente")
        """)

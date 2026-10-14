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

    def test_industry_productivity_uses_explicit_real_lua_userdata_fields(self):
        self.fleet_check("""
            local obj, reads = io.stdout, 0
            local original = debug.getmetatable(obj)
            debug.setmetatable(obj, {
                __index=function(_,key)
                    reads=reads+1
                    if key=="producing" then return false end
                    if key=="boostFromRule" then return true end
                    if key=="boostFromPersonCapacity" then return false end
                    error("campo non dichiarato")
                end,
                __pairs=function() error("non enumerare userdata") end,
                __tostring=function() error("non convertire userdata") end
            })
            local ok,out=pcall(function() return CC.normalizeIndustryProductivity(obj) end)
            debug.setmetatable(obj,original)
            assert(ok and reads==3 and out.available and out.producing==false
                and out.boostFromRule==true and out.boostFromPersonCapacity==false
                and getmetatable(out)==nil and #out.errors==0,
                "indicatori userdata non copiati esplicitamente o false perso")
        """)


    def coast_probe_check(self, setup, assertion):
        source = (DEV / "sonde/s41_normale_costa.lua").read_text(encoding="utf-8")
        # Execute the actual standalone probe under Lua; terrain is synthetic,
        # every command, filesystem write and process launch is forbidden.
        pre = """
            local forbidden = function() error("sonda non in sola lettura") end
            api = {engine={util={}}, type={Vec2f={new=function(x,y)
                return {x=x,y=y} end}}, cmd=setmetatable({}, {__index=function()
                return forbidden end})}
            io, os = nil, nil
        """
        lua_runtime.run(pre + setup + "\nlocal out=(function()\n" + source
                        + "\nend)()\n" + assertion, library=self.library,
                        name="normale-costa-sonda")

    def test_coast_probe_failed_reads_are_not_dry_land(self):
        self.coast_probe_check("""
            api.engine.terrain={isOnWater=function() error('fixture-private-error') end}
        """, """
            local r=out.lissone_stock_origine.r100
            assert(r.available == false and r.read_errors == 144 and r.read_count == 0
                and r.wet_fraction == nil and r.nx == nil and r.ny == nil,
                "letture fallite appaiono come terreno asciutto")
        """)

    def test_coast_probe_missing_api_returns_diagnostic(self):
        self.coast_probe_check("", """
            local r=out.lissone_stock_origine.r100
            assert(r.available == false and r.error == 'terrain_api_unavailable'
                and r.nx == nil and r.wet_fraction == nil,
                "API mancante non segnalata")
        """)

    def test_coast_probe_partial_reads_do_not_report_normal(self):
        self.coast_probe_check("""
            local calls=0
            api.engine.terrain={isOnWater=function(p)
                calls=calls+1
                if calls%2==0 then return nil end
                return p.x > -5470.74
            end}
        """, """
            local r=out.lissone_stock_origine.r100
            assert(r.available == false and r.read_errors == 72 and r.read_count == 72
                and r.nx == nil and r.ny == nil and r.wet_fraction == nil,
                "campionamento incompleto inventa una normale")
        """)

    def test_coast_probe_boolean_dry_samples_remain_valid(self):
        self.coast_probe_check("""
            api.engine.util.terrain={isOnWater=function() return false end}
        """, """
            local r=out.lissone_stock_origine.r100
            assert(r.available == true and r.read_count == 144 and r.read_errors == 0
                and r.wet_fraction == 0 and r.nx == nil and r.ny == nil,
                "terreno asciutto confuso con letture mancanti")
        """)

    def test_coast_probe_valid_half_plane_preserves_direction(self):
        self.coast_probe_check("""
            api.engine.terrain={isOnWater=function(p)
                return .775671*(p.x+5470.74)-.631137*(p.y+4927.97)>0
            end}
        """, """
            local r=out.lissone_stock_origine.r100
            assert(r.available == true and r.read_count == 144 and r.read_errors == 0
                and math.abs(r.nx-.775671)<.05 and math.abs(r.ny+.631137)<.05
                and math.abs(r.wet_fraction-.5)<.02,
                "letture valide cambiano il verso della costa")
        """)

    def test_coast_probe_non_boolean_water_is_not_accepted(self):
        self.coast_probe_check("""
            api.engine.terrain={isOnWater=function() return 1 end}
        """, """
            local r=out.lissone_stock_origine.r100
            assert(r.available == false and r.read_errors == 144
                and r.wet_fraction == nil and r.nx == nil,
                "risposta non booleana accettata come campione")
        """)

    def native_route_check(self, assertion):
        self.fleet_check("""
            CC.comp=function(id, kind)
                if kind == api.type.ComponentType.LINE then return {} end
                if kind == api.type.ComponentType.GAME_TIME then return {gameTime=5000} end
            end
            CC.lineModes=function() return {12} end
            CC.lineVehicles=function() return {901} end
            CC.lineGroups=function() return {101,102} end
            CC.lineStops=function() return {{stationGroup=101},{stationGroup=102}} end
            CC.lineStopNode=function() return 1 end
            CC.hasPath=function() return true end
            CC.groupPath=function() return true end
            CC.depotForLine=function() return 201 end
            CC.groupCatchables=function() return 1 end
            CC.groupLineCounts=function() return {} end
            CC.vehicleState=function() return 'AT_TERMINAL' end
            CC.vehiclePos=function() return nil end
            CC.lineStats=function() return {} end
        """ + assertion)

    def test_native_route_unavailable_does_not_certify_water_line(self):
        self.native_route_check("""
            api.engine.util.line=nil
            local r=CC.checkLine(900)
            assert(not r.ok and r.native_route.available==false
                and r.problems[1]=='percorso navale nativo non verificabile',
                'API assente certifica linea navale dal solo percorso generico')
        """)

    def test_native_route_incomplete_or_invalid_flags_are_unverified(self):
        self.native_route_check("""
            local cases={{}, {{ {noPath=false} }}, {{},{ {noPath=false} }},
                {{ {} },{ {noPath=false} }}, {{ {noPath=0} },{ {noPath=false} }}}
            for _,flags in ipairs(cases) do
                api.engine.util.line={getDetailedLineProblems=function() return flags end}
                local r=CC.checkLine(900)
                assert(not r.ok and r.native_route.available==false,
                    'risposta nativa incompleta o invalida certifica il percorso')
            end
        """)

    def test_native_route_valid_flags_preserve_success_and_real_missing_path(self):
        self.native_route_check("""
            local flags={{ {noPath=false} },{ {noPath=false} }}
            api.engine.util.line={getDetailedLineProblems=function() return flags end}
            local r=CC.checkLine(900)
            assert(r.ok and r.native_route.available==true, 'percorso completo valido non riconosciuto')
            flags[1][1].noPath=true
            r=CC.checkLine(900)
            assert(not r.ok and r.native_route.available==true
                and r.problems[1]:find('nessun percorso',1,true),
                'percorso realmente mancante confuso con dato illeggibile')
        """)

    def test_native_route_read_error_is_fixed_and_ground_line_unchanged(self):
        self.native_route_check("""
            local calls=0
            api.engine.util.line={getDetailedLineProblems=function()
                calls=calls+1; error('fixture-private-error') end}
            local r=CC.checkLine(900)
            assert(not r.ok and r.native_route.available==false
                and r.native_route.error=='percorso navale nativo non verificabile',
                'errore nativo nascosto o riportato grezzo')
            CC.lineModes=function() return {1} end
            r=CC.checkLine(900)
            assert(r.ok and r.native_route==nil and calls==1, 'linea terrestre alterata')
        """)

    def test_native_route_fallback_matches_verified_ship_enums(self):
        self.native_route_check("""
            api.type.enum.TransportMode.SHIP=nil
            api.type.enum.TransportMode.SMALL_SHIP=nil
            api.engine.util.line={getDetailedLineProblems=function()
                return {{ {noPath=true} },{ {noPath=true} }} end}
            for _,mode in ipairs({10,12}) do
                CC.lineModes=function() return {mode} end
                local r=CC.checkLine(900)
                assert(not r.ok and r.native_route.available==true, 'modo navale provato non riconosciuto')
            end
            CC.lineModes=function() return {13} end
            assert(CC.checkLine(900).native_route==nil, 'modo13 dichiarato navale senza prova')
        """)

    def movement_check(self, assertion):
        self.native_route_check("""
            CC.lineModes=function() return {1} end
            CC._samples={[901]={x=10,y=20,t=4000}}
            CC.vehiclePos=function() return {x=10,y=20} end
        """ + assertion)

    def test_stationary_terminal_or_depot_is_waiting_not_moving(self):
        self.movement_check("""
            for _,state in ipairs({'AT_TERMINAL','IN_DEPOT'}) do
                CC._samples={[901]={x=10,y=20,t=4000}}
                CC.vehicleState=function() return state end
                local r=CC.checkLine(900)
                assert(r.vehicles_moving==0 and r.vehicles_still==0 and r.vehicles_waiting==1
                    and r.movement_unknown==0, 'sosta senza spostamento certificata come movimento')
                assert(r.ok==(state=='AT_TERMINAL'), 'deposito o terminale perdono il collaudo corretto')
            end
        """)

    def test_stationary_en_route_remains_a_problem(self):
        self.movement_check("""
            CC.vehicleState=function() return 'EN_ROUTE' end
            local r=CC.checkLine(900)
            assert(not r.ok and r.vehicles_moving==0 and r.vehicles_still==1
                and r.vehicles_waiting==0 and r.movement_unknown==0,
                'veicolo in viaggio bloccato diventato sosta attesa')
        """)

    def test_real_displacement_remains_movement_even_on_terminal_arrival(self):
        self.movement_check("""
            CC.vehiclePos=function() return {x=20,y=20} end
            local r=CC.checkLine(900)
            assert(r.ok and r.vehicles_moving==1 and r.vehicles_still==0
                and r.vehicles_waiting==0 and r.movement_unknown==0,
                'spostamento misurato perso per stato terminale')
        """)

    def test_missing_or_same_time_sample_is_still_unknown(self):
        self.movement_check("""
            CC._samples={}
            local r=CC.checkLine(900)
            assert(r.vehicles_moving==0 and r.vehicles_waiting==0 and r.movement_unknown==1
                and r.movement_unknown_reasons.no_previous==1, 'primo campione inventa sosta o movimento')
            r=CC.checkLine(900)
            assert(r.vehicles_moving==0 and r.vehicles_waiting==0 and r.movement_unknown==1
                and r.movement_unknown_reasons.time_not_advanced==1, 'tempo fermo inventa movimento')
        """)

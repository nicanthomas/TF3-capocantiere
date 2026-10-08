-- Test della bozza SENZA gioco: un finto "api" minimo (Lua 5.4 sul PC di sviluppo).
-- Controlla la parte di logica che non dipende dal gioco: registro delle entita' create, azioni annidate,
-- pulizia dopo un fallimento, annulla, controllo degli argomenti, copia dei veicoli di una linea.
-- Uso: python3 dev-notes/bozza/run_mock.py   (concatena questo file + cc_lib + cc_actions + bozza + test_mock_casi.lua)

local W = { comps = {}, nextId = 1000, sent = {}, removedCons = {}, removedEdges = {}, sold = {}, destroyedLines = {} }
local CTn = {}
for _, n in ipairs({ "CONSTRUCTION", "BASE_EDGE", "BASE_EDGE_STREET", "BASE_NODE", "LINE", "TRANSPORT_VEHICLE", "STATION_GROUP",
	"STATION", "PLAYER_OWNED", "GAME_TIME", "GAME_SPEED", "INDUSTRY", "TOWN", "VEHICLE_DEPOT", "BOUNDING_VOLUME", "BASE_NODE_CONFIG",
	"TOWN_BUILDING", "FIELD", "SIM_BUILDING" }) do CTn[n] = n end

local function newEnt(comps) W.nextId = W.nextId + 1; W.comps[W.nextId] = comps; return W.nextId end
local WORLD = newEnt({ GAME_TIME = { gameTime = 5000 }, GAME_SPEED = { speedup = 1 } })

-- i vettori del gioco hanno :size() e :at(i); CC.each li gestisce
local function V(t) return setmetatable({}, { __index = function(_, k) if k == "size" then return function() return #t end elseif k == "at" then return function(_, i) return t[i] end end end }) end

api = {
	type = {
		ComponentType = CTn,
		enum = { TransportMode = { BUS = 1, TRAM = 2, ELECTRIC_TRAM = 3, TRUCK = 4, TRAIN = 5, ELECTRIC_TRAIN = 6 },
			Carrier = { ROAD = 0, RAIL = 1 }, RoadType = { STREET = 0, TRACK = 1 }, EdgeObjectType = {} },
		Vec2f = { new = function(x, y) return { x = x, y = y } end },
		Vec3f = { new = function(x, y, z) return { x = x, y = y, z = z } end },
		SimpleProposal = { new = function() return { streetProposal = {} } end },
		TransportVehicleConfig = { new = function() return {} end },
		Line = { Stop = { new = function() return {} end }, new = function() return {} end },
		StationTerminal = { new = function() return {} end },
		Context = { new = function() return {} end },
	},
	engine = {
		getEntitiesWithComponent = function(t) local out = {} for e, c in pairs(W.comps) do if c[t] then out[#out + 1] = e end end table.sort(out) return V(out) end,
		entityExists = function(e) return W.comps[e] ~= nil end,
		getComponent = function(e, t) local c = W.comps[e]; return c and c[t] end,
		util = {
			getWorld = function() return WORLD end,
			getPlayer = function() return 7 end,
			getYear = function() return 2300 end,
			getEntityName = function(e) return "E" .. tostring(e) end,
			proposal = {
				makeProposalData = function(p) if p.boom then error("Unknown exception") end return { errorState = { critical = p.bad == true, messages = V({ p.bad and "Collisione" or nil }) } } end,
				createProposalRemove = function(con) return { remove = con } end,
			},
			octree = { findEntitiesInCircle = function() return V({}) end },
			pathfinding = { findPathNodeToNode = function() return V({ 1 }) end },
		},
		system = {
			transportVehicleSystem = { getLineVehicles = function(L) local out = {} for e, c in pairs(W.comps) do if c.TRANSPORT_VEHICLE and c.TRANSPORT_VEHICLE.line == L then out[#out + 1] = e end end table.sort(out) return V(out) end },
			streetSystem = { getNode2SegmentMap = function() return {} end, getNodeSegments = function() return V({}) end },
			streetConnectorSystem = { getConstructionEntityForEdge = function() return -1 end },
		},
	},
	cmd = {
		sendCommand = function(cmd, cb)
			W.sent[#W.sent + 1] = cmd
			local ok, res, ents = true, {}, {}
			if cmd.kind == "build" then
				if cmd.prop and cmd.prop.remove then W.removedCons[#W.removedCons + 1] = cmd.prop.remove; W.comps[cmd.prop.remove] = nil
				elseif cmd.prop and cmd.prop.streetProposal and cmd.prop.streetProposal.edgesToRemove then
					for _, e in ipairs(cmd.prop.streetProposal.edgesToRemove) do W.removedEdges[#W.removedEdges + 1] = e; W.comps[e] = nil end
				elseif cmd.prop and cmd.prop.make then ents = cmd.prop.make() end
			elseif cmd.kind == "sell" then for _, v in ipairs(cmd.list) do W.sold[#W.sold + 1] = v; W.comps[v] = nil end
			elseif cmd.kind == "destroyLine" then W.destroyedLines[#W.destroyedLines + 1] = cmd.line; W.comps[cmd.line] = nil
			elseif cmd.kind == "buy" then local v = newEnt({ TRANSPORT_VEHICLE = { line = nil, transportVehicleConfig = { vehicles = cmd.cfg.vehicles } } }); res.resultVehicleEntity = v
			elseif cmd.kind == "setLine" then W.comps[cmd.v].TRANSPORT_VEHICLE.line = cmd.line
			end
			if cb then cb(res, ok, ents) end
		end,
		makeWorldBuildProposalCmd = function(prop) return { kind = "build", prop = prop } end,
		makeVehicleSellCmd = function(list) return { kind = "sell", list = list } end,
		makeLineDestroyCmd = function(L) return { kind = "destroyLine", line = L } end,
		makeVehicleBuyCmd = function(_, depot, cfg) return { kind = "buy", depot = depot, cfg = cfg } end,
		makeVehicleSetLineCmd = function(v, line, stop) return { kind = "setLine", v = v, line = line, stop = stop } end,
		makeSetNameCmd = function() return { kind = "name" } end,
	},
	res = { modelRep = { getName = function(id) return "::/vehicle/bus/m" .. id .. ".mdl" end } },
}
function ug_require() return { makePart = function(id) return { part = { modelId = id, compartment2loadConfig = V({ 1 }) } } end } end
function toPlain(x) return x end
-- ---------------------------------------------------------------- il codice vero viene concatenato qui sotto

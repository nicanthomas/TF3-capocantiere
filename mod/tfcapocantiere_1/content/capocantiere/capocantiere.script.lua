-- Capo Cantiere - mod Lua (passo 3: esportazione dello stato)
--
-- Risultati del test di I/O (passo 2), verificati in gioco:
--   * lato interfaccia (guiUpdate): app.saveUserdata / loadUserdata / getAllUserdata FUNZIONANO
--     e scrivono in <dati utente>/<cartella>/<nome>.lua (dalla 40420: mod_presets/capocantiere_<nome>.lua)
--   * lato simulazione (update): app NON e' disponibile, api.gui non esiste
--   * io, dofile, loadfile non esistono; os ha solo time/clock/date/getenv
-- Quindi tutto lo scambio di file avviene nel lato interfaccia. Da li' si legge lo stato
-- del motore (api.engine, sola lettura) e si inviano comandi con api.cmd.sendCommand.
--
-- Il gioco ricrea spesso lo stato Lua degli script: i dati che devono durare stanno
-- nello stato dello script (guiState:get()/set()), non in variabili locali.

-- Cartella di scambio. Dalla build 40420 (08.10.2026) app.*Userdata accetta solo le cartelle del gioco
-- (mod_presets, biomes, heightmaps, towns_industries): "capocantiere" da' "The directory you trying to access is
-- not available or invalid". Si usa mod_presets con il prefisso "capocantiere_" su tutti i nomi dei file.
local DIR = "mod_presets"
local FP = "capocantiere_"
local EXPORT_INTERVAL = 10      -- secondi tra due esportazioni di state.lua
local STATE_VERSION = 1
local CC_VERSION = "v14-bozza-399dcf74"

local function L(msg)
	local text = "[CAPOCANTIERE] " .. tostring(msg)
	local ok = false
	if type(log) == "table" and type(log.message) == "function" then
		ok = pcall(log.message, text)
	end
	if not ok then
		print(text)
	end
end

-- ---------------------------------------------------------------- utilita'

local function round(n)
	if type(n) ~= "number" then return nil end
	return math.floor(n + 0.5)
end

local function nameOf(e)
	local ok, n = pcall(api.engine.util.getEntityName, e)
	if ok and n then return n end
	return ""
end

-- Centro del bounding box dell'entita' (come entity_util.getPosition del gioco).
local function bboxCenter(e)
	local ok, bv = pcall(api.engine.getComponent, e, api.type.ComponentType.BOUNDING_VOLUME)
	if ok and bv and bv.bbox then
		local mn, mx = bv.bbox.min, bv.bbox.max
		return { x = round((mn.x + mx.x) / 2), y = round((mn.y + mx.y) / 2), z = round((mn.z + mx.z) / 2) }
	end
	return nil
end

-- Posizione di una stazione: prima la stazione, poi la sua costruzione.
local function stationPos(station)
	local p = bboxCenter(station)
	if p then return p end
	local ok, con = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, station)
	if ok and con and con >= 0 then
		return bboxCenter(con)
	end
	return nil
end

local function cargoName(id)
	local ok, ct = pcall(api.res.cargoTypeRep.get, id)
	if ok and ct and ct.name then return ct.name end
	local ok2, rn = pcall(api.res.cargoTypeRep.getName, id)
	if ok2 and rn then return rn end
	return tostring(id)
end

local function cargoList(ids)
	local out = {}
	for _, id in ipairs(ids or {}) do
		out[#out + 1] = cargoName(id)
	end
	return out
end

local CARRIER_NAMES = nil
local function carrierName(c)
	if CARRIER_NAMES == nil then
		CARRIER_NAMES = {}
		for _, n in ipairs({ "ROAD", "RAIL", "TRAM", "OTHER", "AIR", "WATER" }) do
			local ok, v = pcall(function() return api.type.enum.Carrier[n] end)
			if ok and v ~= nil then CARRIER_NAMES[tostring(v)] = n end
		end
	end
	return CARRIER_NAMES[tostring(c)] or tostring(c)
end

local function ownedByPlayer(e, player)
	local ok, po = pcall(api.engine.getComponent, e, api.type.ComponentType.PLAYER_OWNED)
	return ok and po ~= nil and po.player == player
end

local function entitiesWith(componentType)
	local ok, list = pcall(api.engine.getEntitiesWithComponent, componentType)
	if ok and list then return list end
	return {}
end

-- ---------------------------------------------------------------- esportazione

local function exportTowns(errors)
	local towns = {}
	for _, e in ipairs(entitiesWith(api.type.ComponentType.TOWN)) do
		local ok, err = pcall(function()
			local t = { id = e, name = nameOf(e), pos = bboxCenter(e) }
			local okS, stations = pcall(api.engine.system.stationSystem.getStations, e)
			if okS and stations then t.numStations = #stations end
			towns[#towns + 1] = t
		end)
		if not ok then errors[#errors + 1] = "town " .. tostring(e) .. ": " .. tostring(err) end
	end
	return towns
end

local function exportIndustries(errors)
	local inds = {}
	for _, e in ipairs(entitiesWith(api.type.ComponentType.INDUSTRY)) do
		local ok, err = pcall(function()
			local ind = api.engine.getComponent(e, api.type.ComponentType.INDUSTRY)
			local item = { id = e, name = nameOf(e), pos = bboxCenter(e), level = ind and ind.level }
			if ind and ind.construction and ind.construction >= 0 then
				local con = api.engine.getComponent(ind.construction, api.type.ComponentType.CONSTRUCTION)
				if con then item.type = con.fileName end
				if not item.pos then item.pos = bboxCenter(ind.construction) end
			end
			if ind and ind.stockList and ind.stockList >= 0 then
				local okIO, io2 = pcall(api.engine.util.stock.getInputsOutputsFromRules, ind.stockList)
				if okIO and io2 then
					item.inputs = cargoList(io2[1])
					item.outputs = cargoList(io2[2])
				else
					errors[#errors + 1] = "industry " .. tostring(e) .. " cargo: " .. tostring(io2)
				end
			end
			inds[#inds + 1] = item
		end)
		if not ok then errors[#errors + 1] = "industry " .. tostring(e) .. ": " .. tostring(err) end
	end
	return inds
end

local function exportStations(errors, player)
	local groups = {}
	for _, g in ipairs(entitiesWith(api.type.ComponentType.STATION_GROUP)) do
		local ok, err = pcall(function()
			local sg = api.engine.getComponent(g, api.type.ComponentType.STATION_GROUP)
			local item = { id = g, name = nameOf(g), stations = {} }
			for _, s in ipairs(sg and sg.stations or {}) do
				local st = { id = s }
				if ownedByPlayer(s, player) or ownedByPlayer(g, player) then item.player = true end
				local okC, isCargo = pcall(api.engine.util.station.isStationOfType, s, true)
				if okC then st.cargo = isCargo end
				local okT, town = pcall(api.engine.system.stationSystem.getTown, s)
				if okT and town and town >= 0 then
					st.town = town
					item.town = item.town or town
				end
				st.pos = stationPos(s)
				item.pos = item.pos or st.pos
				item.stations[#item.stations + 1] = st
			end
			local okCar, car = pcall(api.engine.system.stationGroupSystem.getCarriers, g, -1, -1)
			if okCar and car then
				item.carriers = {}
				for _, c in ipairs(car[1] or {}) do item.carriers[#item.carriers + 1] = carrierName(c) end
			end
			groups[#groups + 1] = item
		end)
		if not ok then errors[#errors + 1] = "station group " .. tostring(g) .. ": " .. tostring(err) end
	end
	return groups
end

local function exportLines(errors, player)
	local lines = {}
	local okL, list = pcall(api.engine.system.lineSystem.getLinesForPlayer, player)
	for _, e in ipairs(okL and list or {}) do
		local ok, err = pcall(function()
			local line = api.engine.getComponent(e, api.type.ComponentType.LINE)
			local item = { id = e, name = nameOf(e), stops = {} }
			for _, stop in ipairs(line and line.stops or {}) do
				item.stops[#item.stops + 1] = { stationGroup = stop.stationGroup, station = stop.station, terminal = stop.terminal }
			end
			local okV, veh = pcall(api.engine.system.transportVehicleSystem.getLineVehicles, e)
			item.vehicles = okV and veh and #veh or 0
			local okM, modes = pcall(api.engine.util.line.getLineTransportModesUnion, e)
			if okM and modes then
				item.transportModes = {}
				for m, on in pairs(modes) do
					if on then item.transportModes[#item.transportModes + 1] = tostring(m) end
				end
			end
			lines[#lines + 1] = item
		end)
		if not ok then errors[#errors + 1] = "line " .. tostring(e) .. ": " .. tostring(err) end
	end
	return lines
end

local function exportDepots(errors, player)
	local depots = {}
	for _, e in ipairs(entitiesWith(api.type.ComponentType.VEHICLE_DEPOT)) do
		local ok, err = pcall(function()
			local d = api.engine.getComponent(e, api.type.ComponentType.VEHICLE_DEPOT)
			local item = { id = e, name = nameOf(e), carrier = d and carrierName(d.carrier), pos = bboxCenter(e), player = ownedByPlayer(e, player) }
			if not item.pos then
				local okC, con = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForDepot, e)
				if okC and con and con >= 0 then item.pos = bboxCenter(con) end
			end
			depots[#depots + 1] = item
		end)
		if not ok then errors[#errors + 1] = "depot " .. tostring(e) .. ": " .. tostring(err) end
	end
	return depots
end

local function buildState()
	local errors = {}
	local player = api.engine.util.getPlayer()
	local s = {
		version = STATE_VERSION,
		generatedAt = os.time(),
		player = player,
	}
	local okY, year = pcall(api.engine.util.getYear)
	if okY then s.year = year end
	s.modVersion = CC_VERSION
	pcall(function() s.gameTime = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME).gameTime end)
	pcall(function() local d = game.interface.getGameTime().date; s.date = { year = d.year, month = d.month, day = d.day } end)
	pcall(function() s.gameBuild = api.util.getBuildVersion() end)
	pcall(function() s.speed = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup end)
	local okM, money = pcall(api.engine.util.finance.getPlayersBalance, player)
	if okM then s.money = money else errors[#errors + 1] = "money: " .. tostring(money) end
	s.noCosts = (okM and money == nil) or nil

	local sections = {
		{ "towns", exportTowns },
		{ "industries", exportIndustries },
		{ "stations", function(e) return exportStations(e, player) end },
		{ "lines", function(e) return exportLines(e, player) end },
		{ "depots", function(e) return exportDepots(e, player) end },
	}
	for _, sec in ipairs(sections) do
		local ok, res = pcall(sec[2], errors)
		if ok then
			s[sec[1]] = res
		else
			errors[#errors + 1] = sec[1] .. ": " .. tostring(res)
			s[sec[1]] = {}
		end
	end
	-- merci accettate dalle citta' (uguali per tutte: dipendono dal tipo di zona)
	pcall(function()
		local acc, names = {}, {}
		for _, list in pairs(api.engine.util.town.getLandUse2CargoTypes()) do
			local ids = {}
			if type(list) == "table" then
				for _, id in ipairs(list) do ids[#ids + 1] = id end
			else
				-- vettore nativo: mai ipairs (ciclo infinito), solo size/at
				for i = 1, list:size() do ids[#ids + 1] = list:at(i) end
			end
			for _, id in ipairs(ids) do
				if not acc[id] then acc[id] = true; names[#names + 1] = cargoName(id) end
			end
		end
		table.sort(names)
		s.townAcceptedCargo = names
	end)
	s.errors = errors
	return s
end

local CURRENT_G = nil   -- stato GUI del tick corrente (per lastActionId)

local function exportState()
	local t0 = os.clock()
	local s = buildState()
	s.lastActionId = CURRENT_G and CURRENT_G.lastActionId or 0
	app.saveUserdata(DIR, FP .. "state", s)
	return s, os.clock() - t0
end

-- ---------------------------------------------------------------- azioni (dal middleware)
--
-- Protocollo file (cartella <dati utente>/capocantiere). Gli id sono progressivi: 1, 2, 3...
--   actions_<id>_<nonce>.lua  scritto dal middleware: { id = <id>, nonce = "<nonce>", actions = { {type=...}, ... } }
--   results_<id>_<nonce>.lua  scritto dalla mod:      { id = <id>, nonce = ..., results = {...}, finishedAt = ... }
-- Il nonce e' casuale e diverso per ogni richiesta: app.loadUserdata tiene in memoria (per tutta la
-- durata del processo del gioco) il contenuto dei file gia' letti, quindi un nome di file non va
-- MAI riusato (verificato: rileggere actions_1 dopo aver ricaricato la partita dava il vecchio contenuto).
-- La mod trova il file con app.getAllUserdata (che vede i file creati da fuori).
-- L'ultimo id eseguito sta nello stato GUI ed e' esportato in state.lua (lastActionId).

local ACTION_POLL = 1           -- secondi tra due controlli di actions.lua
local handlers = {}

handlers.set_speed = function(a)
	api.cmd.sendCommand(api.cmd.makeGameSetSpeedCmd(tonumber(a.speed) or 1))
	return { ok = true }
end

handlers.ping = function(a)
	return { ok = true, pong = a.text or "pong", time = os.time() }
end

handlers.export_now = function(a)
	local st = exportState()
	return { ok = true, towns = #st.towns, industries = #st.industries, stations = #st.stations, lines = #st.lines }
end

-- Converte qualsiasi valore in dati semplici salvabili (userdata -> stringa, profondita' limitata).
local function toPlain(v, depth)
	depth = depth or 0
	local t = type(v)
	if t == "nil" or t == "boolean" or t == "number" or t == "string" then return v end
	if t == "table" and depth < 6 then
		local out, n = {}, 0
		for k, x in pairs(v) do
			n = n + 1
			if n > 500 then out["..."] = "troncato"; break end
			local kk = (type(k) == "number" or type(k) == "string") and k or tostring(k)
			out[kk] = toPlain(x, depth + 1)
		end
		return out
	end
	return tostring(v)
end

-- SOLO SVILUPPO: esegue codice Lua scritto dal middleware nella cartella capocantiere.
-- Serve per provare le funzioni dell'API senza ricaricare la partita. Il codice gira nella
-- stessa sandbox della mod (niente io, niente os.execute). Nel repo e' SPENTO: la copia per le prove si crea con
-- python dev-notes/build_script.py --dev  (dist/tfcapocantiere_1_dev, DEV_MODE = true).
local DEV_MODE = false
local DEV = { log = {} }   -- tabella del modulo: le callback dei comandi possono scriverci
local SIM_SNAPSHOT = nil  -- ultimo stato del lato simulazione visto dalla GUI (solo sviluppo)

handlers.dev_events = function(a)
	return { ok = true, guiEvents = DEV.seenList or {}, simEvents = SIM_SNAPSHOT and SIM_SNAPSHOT.seen or {} }
end

handlers.sim_eval = function(a)
	if not DEV_MODE then error("disattivato") end
	local key = tostring(a.key or os.time())
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("capocantiere.script", "capocantiere", "eval", { key = key, code = a.code }))
	return { ok = true, queued = key }
end

handlers.sim_result = function(a)
	local jobs = SIM_SNAPSHOT and SIM_SNAPSHOT.jobs or {}
	local r = jobs[tostring(a.key)]
	if not r then return { ok = false, pending = true } end
	return { ok = true, job = r }
end

handlers.lua_eval = function(a)
	if not DEV_MODE then error("lua_eval disattivato") end
	local env = setmetatable({ dev = DEV, L = L, toPlain = toPlain }, { __index = _G })
	local f, err = load(a.code, "=capocantiere_eval", "t", env)
	if not f then error("compilazione: " .. tostring(err)) end
	local res = f()
	return { ok = true, value = toPlain(res) }
end

-- Azioni di costruzione: eseguite nel lato simulazione (vedi SIM_ACTIONS). La GUI le inoltra con un
-- evento e scrive il file results solo quando il lato simulazione ha finito (o dopo SIM_TIMEOUT s).
local SIM_TYPES = {
	build_station = true, build_line = true, buy_and_assign_vehicles = true,
	build_bus_line = true, build_tram_line = true, connect_industry_to_city = true,
	build_rail_line = true,
}
local SIM_TIMEOUT = 300   -- le ferrovie lunghe possono richiedere qualche minuto

local function sendSimAction(key, a)
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("capocantiere.script", "capocantiere", "action", { key = key, action = a }))
end

local function hasUserdata(name)
	local ok, list = pcall(app.getAllUserdata, DIR)
	if not ok or type(list) ~= "table" then return false end
	for _, n in ipairs(list) do
		if n == name then return true end
	end
	return false
end

local function findActionFile(nextId)
	local ok, list = pcall(app.getAllUserdata, DIR)
	if not ok or type(list) ~= "table" then return nil end
	local prefix = FP .. "actions_" .. nextId .. "_"
	for _, n in ipairs(list) do
		if n:sub(1, #prefix) == prefix then return n end
	end
	return nil
end

local function runActions(g)
	local nextId = (g.lastActionId or 0) + 1
	local fname = findActionFile(nextId)
	if not fname then return end
	local ok, req = pcall(app.loadUserdata, DIR, fname)
	if not ok or type(req) ~= "table" or req.id ~= nextId then return end
	local nonce = tostring(req.nonce or fname:sub(#(FP .. "actions_" .. nextId .. "_") + 1))

	L("eseguo richiesta azioni id " .. tostring(req.id))
	local results = {}
	for i, a in ipairs(req.actions or {}) do
		local h = type(a) == "table" and handlers[a.type] or nil
		local r
		if type(a) == "table" and (SIM_TYPES[a.type] or (a.type and not handlers[a.type])) then
			local key = "a" .. req.id .. "_" .. i .. "_" .. nonce
			local okS, errS = pcall(sendSimAction, key, a)
			if okS then
				r = { ok = false, pending = true, simKey = key }
			else
				r = { ok = false, error = "invio al lato simulazione fallito: " .. tostring(errS) }
			end
		elseif not h then
			r = { ok = false, error = "azione sconosciuta: " .. tostring(a and a.type) }
		else
			local okH, res = pcall(h, a)
			if okH then
				r = type(res) == "table" and res or { ok = true, value = res }
			else
				r = { ok = false, error = tostring(res) }
			end
		end
		r.type = a and a.type
		r.index = i
		results[i] = r
		L("  azione " .. i .. " (" .. tostring(r.type) .. "): " .. (r.pending and "inviata al lato simulazione" or (r.ok and "OK" or ("ERRORE " .. tostring(r.error)))))
	end
	-- l'id viene segnato subito come eseguito e il file azioni rimosso: cosi' un'azione non parte mai due volte
	g.lastActionId = req.id
	pcall(app.removeUserdata, DIR, fname)
	local waiting = false
	for _, r in ipairs(results) do if r.pending then waiting = true end end
	if waiting then
		g.pending = { id = req.id, nonce = nonce, results = results, started = os.time() }
	else
		app.saveUserdata(DIR, FP .. "results_" .. req.id .. "_" .. nonce, { id = req.id, nonce = nonce, results = results, finishedAt = os.time() })
	end
	-- state.lua subito aggiornato: contiene il nuovo lastActionId e gli effetti delle azioni
	CURRENT_G = g
	pcall(exportState)
end

-- ---------------------------------------------------------------- ciclo GUI

local function guiTick(guiState)
	local g = guiState:get() or {}
	CURRENT_G = g
	local now = os.time()
	local changed = false

	if g.pending then
		-- attendo i risultati dal lato simulazione
		local p = g.pending
		local jobs = SIM_SNAPSHOT and SIM_SNAPSHOT.jobs or {}
		local done = true
		for i, r in ipairs(p.results) do
			if r.pending then
				local j = jobs[r.simKey]
				if j then
					local v = type(j.value) == "table" and j.value or {}
					if not j.ok then v = { ok = false, error = j.error } end
					v.type = r.type; v.index = i
					p.results[i] = v
					L("  azione " .. i .. " (" .. tostring(r.type) .. "): " .. (v.ok and "OK" or ("ERRORE " .. tostring(v.error))))
				elseif now - (p.started or now) > SIM_TIMEOUT then
					p.results[i] = { ok = false, error = "nessuna risposta dal lato simulazione (partita in pausa?)", type = r.type, index = i }
				else
					done = false
				end
			end
		end
		if done then
			app.saveUserdata(DIR, FP .. "results_" .. p.id .. "_" .. p.nonce, { id = p.id, nonce = p.nonce, results = p.results, finishedAt = now })
			g.pending = nil
			pcall(exportState)
		end
		changed = true
	elseif not g.lastPoll or now - g.lastPoll >= ACTION_POLL then
		g.lastPoll = now
		changed = true
		local ok, err = pcall(runActions, g)
		if not ok then L("errore azioni: " .. tostring(err)) end
	end

	if not g.lastExport or now - g.lastExport >= (g.exportInterval or EXPORT_INTERVAL) then
		g.lastExport = now
		g.exports = (g.exports or 0) + 1
		changed = true
		local ok, st, dt = pcall(exportState)
		if ok and dt then g.exportInterval = math.max(EXPORT_INTERVAL, math.min(60, math.floor(dt * 100))) end
		if ok then
			if g.exports == 1 or #st.errors ~= (g.lastErrCount or 0) then
				g.lastErrCount = #st.errors
				L(string.format("state.lua esportato: %d citta', %d industrie, %d stazioni, %d linee, %d depositi, %d errori (%.0f ms)",
					#st.towns, #st.industries, #st.stations, #st.lines, #st.depots, #st.errors, (dt or 0) * 1000))
				for i = 1, math.min(5, #st.errors) do L("  errore: " .. st.errors[i]) end
			end
		else
			L("esportazione fallita: " .. tostring(st))
		end
	end

	if changed then guiState:set(g) end
end

-- ---------------------------------------------------------------- cattura costruzioni del giocatore (SOLO SVILUPPO)
-- Quando il giocatore costruisce qualcosa con gli strumenti del gioco, salva una descrizione
-- della proposta in mod_presets/capocantiere_captured_<n>.lua: serve a imparare il formato corretto
-- (es. per le fermate su strada) da usare poi nelle azioni automatiche.

local function v3(v)
	if v == nil then return nil end
	local ok, r = pcall(function() return { v.x, v.y, v.z } end)
	return ok and r or tostring(v)
end

-- Converte un vettore (tabella Lua o Vector nativo con :size()/:at(i), indici da 1) in tabella.
local function each(v)
	local out = {}
	if v == nil then return out end
	local okN = pcall(function()
		local n = v:size()
		for i = 1, n do out[#out + 1] = v:at(i) end
	end)
	if okN then return out end
	-- ATTENZIONE: mai ipairs su userdata (un Vector nativo puo' restituire valori per qualsiasi
	-- indice e il ciclo non finisce mai: e' successo, il gioco si e' bloccato)
	out = {}
	if type(v) == "table" then
		for i, x in ipairs(v) do out[i] = x end
	end
	return out
end

local function describeProposal(prop)
	local d = {}
	pcall(function()
		local sp = prop.proposal
		d.addedSegments = {}
		for i, sgm in ipairs(each(sp.addedSegments_native or sp.addedSegments)) do
			local c = sgm.comp
			local item = { entity = sgm.entity, type = sgm.type }
			pcall(function()
				item.node0 = c.node0; item.node1 = c.node1
				item.p0 = v3(c.position0); item.p1 = v3(c.position1)
				item.t0 = v3(c.tangent0); item.t1 = v3(c.tangent1)
				item.roadTemplate = tostring(c.roadTemplate); item.roadStyle = tostring(c.roadStyle)
				item.roadType = tostring(c.roadType); item.typeIndex = c.typeIndex; item.edgeType = tostring(c.type)
				item.objects = {}
				for j, o in ipairs(each(c.objects)) do item.objects[j] = { o[1], tostring(o[2]) } end
			end)
			d.addedSegments[i] = item
		end
		d.removedSegments = {}
		for i, sgm in ipairs(each(sp.removedSegments)) do d.removedSegments[i] = sgm.entity end
		d.addedNodes = {}
		for i, n in ipairs(each(sp.addedNodes_native or sp.addedNodes)) do d.addedNodes[i] = { entity = n.entity, pos = v3(n.comp.position) } end
		d.edgeObjectsToAdd = {}
		for i, o in ipairs(each(sp.edgeObjectsToAdd)) do
			local item = { resultEntity = o.resultEntity, category = o.category, left = o.left, player = o.playerEntity }
			pcall(function()
				item.modelId = o.modelInstance.modelId
				item.modelName = api.res.modelRep.getName(o.modelInstance.modelId)
			end)
			pcall(function() item.modelTransf = toPlain(o.modelInstance.transf) end)
			pcall(function() item.con = tostring(o.edgeObjectConstruction) end)
			pcall(function() item.params = toPlain(o.params) end)
			pcall(function() item.edgeEntity = o.edgeEntity end)
			pcall(function() item.param = o.param end)
			d.edgeObjectsToAdd[i] = item
		end
	end)
	pcall(function()
		d.toAdd = {}
		for i, c in ipairs(each(prop.toAdd_native or prop.toAdd)) do
			d.toAdd[i] = { fileName = tostring(c.fileName), params = toPlain(c.params), player = c.playerEntity }
		end
		d.toRemove = toPlain(prop.toRemove)
	end)
	return d
end

local function captureEvent(src, id, name, param)
	if not DEV_MODE then return end
	local idS, nameS = tostring(id), tostring(name)
	DEV.seen = DEV.seen or {}
	local key = tostring(src) .. " | " .. idS .. " | " .. nameS
	if not DEV.seen[key] and (DEV.seenCount or 0) < 200 then
		DEV.seen[key] = true
		DEV.seenCount = (DEV.seenCount or 0) + 1
		DEV.seenList = DEV.seenList or {}
		DEV.seenList[#DEV.seenList + 1] = key
	end
	if not (idS:find("builder") or idS:find("constructionBuilder") or idS:find("streetBuilder")
			or idS:find("streetTerminal") or nameS:find("proposal") or nameS:find("builder")) then
		return
	end
	if not nameS:lower():find("apply") then return end
	local rec = { src = tostring(src), id = idS, name = nameS, time = os.time() }
	pcall(function()
		-- per builder.proposalApply il parametro e' { Proposal, ProposalData, { Entity } } (vedi mission_sim.script)
		local prop = param[1] or param.proposal
		local pdata = param[2] or param.data
		rec.proposal = describeProposal(prop)
		pcall(function() rec.resultEntities = toPlain(param[3] or param.result) end)
		pcall(function()
			rec.costs = pdata.costs
			rec.critical = pdata.errorState.critical
		end)
		DEV.lastProposal = prop     -- solo sviluppo: riusabile da lua_eval finche' lo stato Lua vive
	end)
	DEV.captureCount = (DEV.captureCount or 0) + 1
	local fn = FP .. "captured_" .. tostring(os.time()) .. "_" .. tostring(DEV.captureCount)
	pcall(app.saveUserdata, DIR, fn, rec)
	L("catturata costruzione del giocatore: " .. idS .. " / " .. nameS .. " -> " .. fn)
end

-- ---------------------------------------------------------------- lavori lato simulazione
-- ===================================================================== CC sim library
-- Funzioni di costruzione eseguite sul LATO SIMULAZIONE (comandi sincroni).
local CC = {}
-- Anno di gioco; CC.YEAR_OVERRIDE serve solo nei test per simulare un'altra epoca.
function CC.year() return CC.YEAR_OVERRIDE or api.engine.util.getYear() end
local CT = api.type.ComponentType

local function each(v)
	local out = {}
	if v == nil then return out end
	local okN = pcall(function()
		local n = v:size()
		for i = 1, n do out[#out + 1] = v:at(i) end
	end)
	if okN then return out end
	out = {}
	if type(v) == "table" then
		for i, x in ipairs(v) do out[i] = x end
	end
	return out
end
CC.each = each

local function comp(e, t)
	local ok, c = pcall(api.engine.getComponent, e, t)
	if ok then return c end
	return nil
end
CC.comp = comp

local function bbox(e)
	local bv = comp(e, CT.BOUNDING_VOLUME)
	if bv and bv.bbox then
		local mn, mx = bv.bbox.min, bv.bbox.max
		return { x = (mn.x + mx.x) / 2, y = (mn.y + mx.y) / 2, z = (mn.z + mx.z) / 2 }
	end
	return nil
end

function CC.nameOf(e)
	local ok, n = pcall(api.engine.util.getEntityName, e)
	if ok and n and n ~= "" then return n end
	return nil
end

-- Posizione di citta', industria, stazione, gruppo di stazioni o costruzione.
function CC.posOf(e)
	if not e or not api.engine.entityExists(e) then return nil end
	local sg = comp(e, CT.STATION_GROUP)
	if sg then
		local st = each(sg.stations)[1]
		if st then return CC.posOf(st) end
	end
	local p = bbox(e)
	if p then return p end
	local ind = comp(e, CT.INDUSTRY)
	if ind and ind.construction and ind.construction >= 0 then return bbox(ind.construction) end
	local ok, con = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, e)
	if ok and con and con >= 0 then return bbox(con) end
	return nil
end

-- Invio sincrono di un comando: ritorna ok, res, entita' create (lista di id)
function CC.send(cmd)
	local R = { ents = {} }
	-- il gioco a volte lancia un'eccezione invece di rifiutare: la tratto come un rifiuto
	local okS, err = pcall(api.cmd.sendCommand, cmd, function(res, ok, ents)
		R.res = res; R.ok = ok
		pcall(function() for _, x in ipairs(ents or {}) do R.ents[#R.ents + 1] = type(x) == "table" and x[1] or x end end)
	end)
	if not okS then R.ok = false; R.exception = tostring(err):sub(1, 120) end
	CC._last = R
	return R.ok == true, R.res, R.ents
end
function CC.lastSend() local R = CC._last or {} return R.ok == true, R.res, R.ents end

local function proposalErrors(res)
	local info = { msg = {}, coll = {}, critical = nil }
	pcall(function()
		local es = res.resultProposalData.errorState
		info.critical = es.critical
		for i, m in ipairs(each(es.messages)) do info.msg[i] = tostring(m) end
	end)
	pcall(function()
		local ci = res.resultProposalData.collisionInfo
		for i, c in ipairs(each(ci.collisionEntities)) do
			if i > 30 then break end
			info.coll[#info.coll + 1] = c.entity
		end
	end)
	return info
end
CC.proposalErrors = proposalErrors

local function isStreetPiece(e)
	return comp(e, CT.BASE_EDGE) ~= nil or comp(e, CT.BASE_NODE) ~= nil
end

function CC.playerGroups()
	local player = api.engine.util.getPlayer()
	local set = {}
	for _, g in ipairs(each(api.engine.getEntitiesWithComponent(CT.STATION_GROUP))) do
		local sg = comp(g, CT.STATION_GROUP)
		local s = sg and each(sg.stations)[1]
		local po = s and comp(s, CT.PLAYER_OWNED)
		if po and po.player == player then set[g] = true end
	end
	return set
end

local function inConstruction(e)
	local ok, c = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForEdge, e)
	return ok and c ~= nil and c >= 0
end
CC.inConstruction = inConstruction

local function edgeLen(be)
	local dx, dy = be.position1.x - be.position0.x, be.position1.y - be.position0.y
	return math.sqrt(dx * dx + dy * dy)
end

-- Segmenti di strada (non ponti/gallerie, senza oggetti) vicino a un punto, ordinati per distanza.
function CC.streetEdgesNear(x, y, r, minLen)
	local out = {}
	local list = api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE)
	for _, e in ipairs(each(list)) do
		local be = comp(e, CT.BASE_EDGE)
		local st = comp(e, CT.BASE_EDGE_STREET)
		if be and st and be.type == 0 and #each(be.objects) == 0 and not inConstruction(e) then
			local L = edgeLen(be)
			if L >= (minLen or 30) then
				local mx, my = (be.position0.x + be.position1.x) / 2, (be.position0.y + be.position1.y) / 2
				out[#out + 1] = { edge = e, d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2), len = L, x = mx, y = my,
					tmpl = tostring(st.streetType) }
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- Fermata stradale (bus/tram) a meta' del segmento e. Ritorna ok, info
function CC.buildStopOnEdge(e, name)
	local be = comp(e, CT.BASE_EDGE)
	if not be then return false, { error = "segmento inesistente" } end
	local before = CC.playerGroups()
	local s = api.type.SegmentAndEntity.new()
	s.entity = -1; s.type = 0; s.comp = be
	s.streetEdge = comp(e, CT.BASE_EDGE_STREET)
	s.comp.objects = { { -400000000, api.type.enum.EdgeObjectType.STOP_RIGHT } }
	local p = api.type.SimpleProposal.new()
	p.streetProposal.edgesToAdd = { s }
	p.streetProposal.edgesToRemove = { e }
	local cfg = {}
	for _, nn in ipairs({ be.node0, be.node1 }) do
		if comp(nn, CT.BASE_NODE_CONFIG) then cfg[#cfg + 1] = nn end
	end
	if #cfg > 0 then p.streetProposal.nodeConfigsToRemove = cfg end
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = -1; o.param = 0.5; o.oneWay = false; o.left = false
	o.model = "::/stations/street/small_stops/small_old.con"
	o.playerEntity = api.engine.util.getPlayer()
	o.name = name or "Fermata"
	p.streetProposal.edgeObjectsToAdd = { o }
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, nil, false, true)
	if not okc then return false, { error = "proposta: " .. tostring(cmd) } end
	local ok, res = CC.send(cmd)
	if not ok then return false, { error = "costruzione rifiutata", detail = proposalErrors(res) } end
	local group
	for g in pairs(CC.playerGroups()) do if not before[g] then group = g end end
	if group then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(group, name)) end) end
	return true, { group = group }
end

-- Costruisce una fermata vicino a (x, y) provando i segmenti piu' vicini.
function CC.buildStopNear(x, y, name, opts)
	opts = opts or {}
	local tried = {}
	local avoid = opts.avoid or {}
	for _, c in ipairs(CC.streetEdgesNear(x, y, opts.radius or 400, opts.minLen or 30)) do
		local far = true
		for _, a in ipairs(avoid) do
			if (a.x - c.x) ^ 2 + (a.y - c.y) ^ 2 < (opts.spacing or 150) ^ 2 then far = false end
		end
		if far then
			local ok, info = CC.buildStopOnEdge(c.edge, name)
			tried[#tried + 1] = { edge = c.edge, ok = ok, error = info.error }
			if ok then
				info.edge = c.edge; info.x = c.x; info.y = c.y; info.tried = tried
				return true, info
			end
			if #tried >= (opts.maxTries or 6) then break end
		end
	end
	return false, { error = "nessun segmento adatto per la fermata", tried = tried }
end

-- Capolinea (nodi con un solo segmento) vicino a un punto, ordinati per distanza.
function CC.deadEndsNear(x, y, r)
	local out, seen = {}, {}
	local list = api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE)
	for _, e in ipairs(each(list)) do
		local be = comp(e, CT.BASE_EDGE)
		if be and comp(e, CT.BASE_EDGE_STREET) and be.type == 0 and not inConstruction(e) then
			for k, n in ipairs({ be.node0, be.node1 }) do
				if not seen[n] then
					seen[n] = true
					if #each(api.engine.system.streetSystem.getNodeSegments(n)) == 1 then
						local p = k == 1 and be.position0 or be.position1
						out[#out + 1] = { node = n, edge = e, x = p.x, y = p.y, d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2) }
					end
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

local DEPOT_CON = {
	road = "::/depots/road/road_depot/road_depot.con",
	tram = "::/depots/road/tram_depot/tram_depot.con",
}
-- posizione locale del nodo libero di collegamento (misurata dalle proposte del gioco)
local DEPOT_C = {
	road = { 0, -35.0 },
	tram = { -1.64813, -37.4153 },
}

-- Deposito davanti a un capolinea, in due passi:
-- 1) la costruzione da sola, con il suo nodo libero di collegamento C a GAP metri dal capolinea
--    (il nodo C sta a y locale -35.0: il tratto d'ingresso interno va da -35.0 a -20.26)
-- 2) un tratto di strada dal capolinea a C.
function CC.buildDepotAtDeadEnd(node, kind, name)
	local GAP, C_LOCAL_Y = 8.0, -35.0
	local segs = each(api.engine.system.streetSystem.getNodeSegments(node))
	if #segs ~= 1 then return false, { error = "non e' un capolinea" } end
	local be = comp(segs[1], CT.BASE_EDGE)
	local first = be.node0 == node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local dx, dy = t.x, t.y
	if first then dx, dy = -dx, -dy end
	local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	local cx, cy, cz = p.x + dx * GAP, p.y + dy * GAP, p.z
	local function attempt(ignoreErrors)
		return CC.placeDepotC(cx, cy, cz, dx, dy, C_LOCAL_Y, kind, name, ignoreErrors)
	end
	local ok, r = attempt(false)
	local forced = false
	if not ok then
		local info = r.detail
		if not info then return false, r end
		if info.critical or #info.coll == 0 then return false, { error = "costruzione non consentita", detail = info } end
		for _, c in ipairs(info.coll) do
			if c >= 0 and not isStreetPiece(c) then return false, { error = "ostacoli non stradali", detail = info } end
		end
		ok, r = attempt(true)
		forced = true
		if not ok then return false, r end
	end
	r.forced = forced
	-- nodo libero C della costruzione: estremo con un solo segmento piu' vicino al capolinea
	local best, bd
	local c = comp(r.construction, CT.CONSTRUCTION)
	local cand = {}
	for _, fn in ipairs(each(c and c.frozenNodes)) do
		cand[#cand + 1] = fn
		for _, sg in ipairs(each(api.engine.system.streetSystem.getNodeSegments(fn))) do
			local b = comp(sg, CT.BASE_EDGE)
			cand[#cand + 1] = b.node0; cand[#cand + 1] = b.node1
		end
	end
	for _, n in ipairs(cand) do
		if n ~= node and #each(api.engine.system.streetSystem.getNodeSegments(n)) == 1 then
			local np = comp(n, CT.BASE_NODE).position
			local d = math.sqrt((np.x - p.x) ^ 2 + (np.y - p.y) ^ 2)
			if not bd or d < bd then best, bd = n, d end
		end
	end
	r.cNode = best; r.cDist = bd
	if best then
		local okC, rc
		if kind == "tram" then
			okC, rc = CC.connectNodes(node, best, CC.tramTemplateFor(tostring(be.roadTemplate)) or CC.tramTemplateFor("::/infrastructure/street/town/town_old_small.street_template"), false)
		else
			okC, rc = CC.connectNodes(node, best, nil, false)
			if not okC then okC, rc = CC.connectNodes(node, best, tostring(be.roadTemplate), false) end
		end
		r.connect = { okC, rc and rc.error }
	end
	r.connected = #each(api.engine.system.streetSystem.getNodeSegments(node)) >= 2
	return r.depot ~= nil, r
end

function CC.buildDepotNear(x, y, kind, name, r)
	local tried = {}
	for _, d in ipairs(CC.deadEndsNear(x, y, r or 900)) do
		local ok, info = CC.buildDepotAtDeadEnd(d.node, kind, name)
		tried[#tried + 1] = { node = d.node, ok = ok, error = info.error }
		if ok then info.tried = tried; info.node = d.node; return true, info end
		if #tried >= 6 then break end
	end
	-- nessun capolinea adatto: creo una diramazione da una strada vicina e riprovo li'
	for _ = 1, 3 do
		local okS, sp = CC.makeSpur(x, y, 30, r or 900)
		if not okS then tried[#tried + 1] = { spur = false, error = sp.error }; break end
		local ok, info = CC.buildDepotAtDeadEnd(sp.node, kind, name)
		tried[#tried + 1] = { node = sp.node, spur = true, ok = ok, error = info.error }
		if ok then info.tried = tried; info.node = sp.node; return true, info end
	end
	return false, { error = "nessun posto adatto per il deposito", tried = tried }
end

-- Depositi del giocatore (entita' deposito) con posizione.
function CC.playerDepots()
	local player = api.engine.util.getPlayer()
	local out = {}
	for _, con in ipairs(each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
		local c = comp(con, CT.CONSTRUCTION)
		if c and #each(c.depots) > 0 then
			local po = comp(con, CT.PLAYER_OWNED)
			if po and po.player == player then
				local p = bbox(con)
				for _, d in ipairs(each(c.depots)) do
					out[#out + 1] = { depot = d, construction = con, file = tostring(c.fileName), x = p and p.x, y = p and p.y }
				end
			end
		end
	end
	return out
end

function CC.createLine(name, groups, color)
	local line = api.type.Line.new()
	local stops = {}
	for i, g in ipairs(groups) do
		local st = api.type.Line.Stop.new()
		st.stationGroup = g; st.station = 0; st.terminal = 0
		-- stazioni con piu' binari: il treno puo' usare qualunque terminal libero
		pcall(function()
			local sg = comp(g, CT.STATION_GROUP)
			local stn = comp(each(sg.stations)[1], CT.STATION)
			local nTerm = #each(stn.terminals)
			if nTerm > 1 then
				local alts = {}
				for t = 1, nTerm - 1 do
					local a = api.type.StationTerminal.new()
					a.station = 0; a.terminal = t
					alts[#alts + 1] = a
				end
				st.alternativeTerminals = alts
			end
		end)
		stops[i] = st
	end
	line.stops = stops
	color = color or { math.random(), math.random(), math.random() }
	local cmd = api.cmd.makeLineCreateCmd(name, api.type.Vec3f.new(color[1], color[2], color[3]),
		api.engine.util.getPlayer(), line)
	local ok, res = CC.send(cmd)
	local e
	pcall(function() e = res.resultEntity end)
	if not ok or not e or e < 0 then return false, { error = "creazione linea rifiutata" } end
	return true, { line = e }
end

-- Modello piu' recente disponibile quest'anno, il cui percorso contiene "/<kind>/".
-- id della merce "passeggeri"
function CC.passengerCargo()
	if CC._pass then return CC._pass end
	local id = 0
	pcall(function() local x = api.res.cargoTypeRep.find("PASSENGERS"); if x and x >= 0 then id = x end end)
	CC._pass = id
	return id
end

-- Capacita' passeggeri e altre merci di un modello.
function CC.modelLoads(modelId)
	local pass, other = 0, 0
	local P = CC.passengerCargo()
	pcall(function()
		local tv = api.res.modelRep.get(modelId).metadata.transportVehicle
		for _, cpt in ipairs(each(tv.compartments)) do
			for _, lc in ipairs(each(cpt.loadConfigs)) do
				local ce = lc.cargoEntry
				local isP, isO = false, false
				pcall(function() api.res.cargoTypeRep.forEachCargoType(ce.cargoTypeSet, function(cid) if cid == P then isP = true else isO = true end end) end)
				if isP then pass = math.max(pass, ce.capacity or 0) end
				if isO then other = math.max(other, ce.capacity or 0) end
			end
		end
	end)
	return pass, other
end

-- Modello piu' recente disponibile quest'anno, il cui percorso contiene "/<kind>/".
-- opts.passengers: solo veicoli con posti passeggeri (quelli misti passeggeri/merci solo se non c'e' altro).
function CC.pickModel(kind, exclude, opts)
	opts = opts or {}
	local year = CC.year()
	local best
	api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(name)
		local skip = false
		for _, x in ipairs(exclude or {}) do if name:find(x, 1, true) then skip = true end end
		if not skip and name:find("/" .. kind .. "/", 1, true) then
			local id = api.res.modelRep.find(name)
			local m = api.res.modelRep.get(id)
			local av = m and m.metadata and m.metadata.availability
			local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
			if from <= year and (to == 0 or to > year) then
				local score = from
				local ok = true
				if opts.passengers then
					local pass, other = CC.modelLoads(id)
					if pass <= 0 then ok = false elseif other > 0 then score = score - 10000 end
				end
				if ok and (not best or score > best.score) then best = { id = id, name = name, from = from, to = to, score = score } end
			end
		end
	end)
	return best
end

function CC.buyVehicles(depot, modelId, count, line, fixedStop)
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local player = api.engine.util.getPlayer()
	local gt = comp(api.engine.util.getWorld(), CT.GAME_TIME)
	local nStops = 1
	if line then
		local lc = comp(line, CT.LINE)
		nStops = math.max(1, #each(lc and lc.stops))
	end
	local bought = {}
	local errors = {}
	for i = 1, count do
		local part = vu.makePart(modelId, true, nil)
		part.purchaseTime = gt and math.floor(gt.gameTime) or 0
		local auto = {}
		for k = 1, math.max(1, #each(part.part.compartment2loadConfig)) do auto[k] = true end
		part.autoLoadConfig = auto
		local cfg = api.type.TransportVehicleConfig.new()
		cfg.vehicles = { part }
		cfg.vehicleGroups = { 1 }
		cfg.muFileNames = {}
		local ok, res = CC.send(api.cmd.makeVehicleBuyCmd(player, depot, cfg))
		local veh
		pcall(function() veh = res.resultVehicleEntity end)
		if ok and veh and veh >= 0 then
			bought[#bought + 1] = veh
			if line then
				local ok2 = CC.send(api.cmd.makeVehicleSetLineCmd(veh, line, fixedStop or ((i - 1) % nStops)))
				if not ok2 then errors[#errors + 1] = "assegnazione linea fallita per " .. veh end
			end
		else
			errors[#errors + 1] = "acquisto " .. i .. " fallito"
			break
		end
	end
	return #bought > 0, { vehicles = bought, errors = errors }
end

-- Segmento di strada dritto tra due nodi esistenti.
function CC.connectNodes(n0, n1, tmplName, ignoreErrors)
	tmplName = tmplName or "::/infrastructure/street/constructions/entrance_new.street_template"
	local a, b = CC.comp(n0, CT.BASE_NODE), CC.comp(n1, CT.BASE_NODE)
	if not a or not b then return false, { error = "nodo inesistente" } end
	local pa, pb = a.position, b.position
	local dx, dy, dz = pb.x - pa.x, pb.y - pa.y, pb.z - pa.z
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(tmplName))
	local s = api.type.SegmentAndEntity.new()
	s.entity = -1
	s.type = 0
	s.comp.node0 = n0; s.comp.node1 = n1
	s.comp.position0 = api.type.Vec3f.new(pa.x, pa.y, pa.z); s.comp.position1 = api.type.Vec3f.new(pb.x, pb.y, pb.z)
	s.comp.tangent0 = api.type.Vec3f.new(dx, dy, dz); s.comp.tangent1 = api.type.Vec3f.new(dx, dy, dz)
	s.comp.type = 0; s.comp.typeIndex = -1
	s.comp.laneConfigs = tmpl.laneConfigs
	s.comp.roadTemplate = tmplName
	s.comp.roadStyle = tmpl.streetStyle
	s.comp.roadType = api.type.enum.RoadType.STREET
	-- componente "strada": copio quello di un segmento vicino e imposto il tipo di strada del modello
	local ref = CC.each(api.engine.system.streetSystem.getNodeSegments(n0))[1]
		or CC.each(api.engine.system.streetSystem.getNodeSegments(n1))[1]
	local se = ref and CC.comp(ref, CT.BASE_EDGE_STREET)
	if se then s.streetEdge = se end
	-- proprieta' del giocatore (le strade costruite dal giocatore ce l'hanno)
	pcall(function()
		local po = api.type.PlayerOwned.new()
		po.player = api.engine.util.getPlayer()
		s.playerOwned = po
	end)
	local p = api.type.SimpleProposal.new()
	p.streetProposal.edgesToAdd = { s }
	-- come per le fermate: tolgo le configurazioni dei nodi, il motore le rigenera con il nuovo tratto
	local cfg = {}
	for _, nn in ipairs({ n0, n1 }) do
		if CC.comp(nn, CT.BASE_NODE_CONFIG) then cfg[#cfg + 1] = nn end
	end
	if #cfg > 0 then p.streetProposal.nodeConfigsToRemove = cfg end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, nil, ignoreErrors == true, true)
	if not okc then return false, { error = "proposta: " .. tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "collegamento rifiutato", detail = proposalErrors(res) } end
	return true, { ents = ents }
end

-- Prolunga un capolinea con un tratto dritto di lunghezza len verso l'esterno (nuovo nodo).
-- Ritorna ok, { node = nuovo nodo, x, y, z, dx, dy }
function CC.extendDeadEnd(node, len, tmplName, endPos)
	local segs = each(api.engine.system.streetSystem.getNodeSegments(node))
	if #segs ~= 1 then return false, { error = "non e' un capolinea" } end
	local be = comp(segs[1], CT.BASE_EDGE)
	local first = be.node0 == node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local dx, dy = t.x, t.y
	if first then dx, dy = -dx, -dy end
	local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	local ex, ey, ez = p.x + dx * len, p.y + dy * len, p.z
	if endPos then ex, ey, ez = endPos[1], endPos[2], endPos[3] end
	local tx, ty, tz = ex - p.x, ey - p.y, ez - p.z
	tmplName = tmplName or tostring(be.roadTemplate)
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(tmplName))
	local prop = api.type.SimpleProposal.new()
	local n = api.type.NodeAndEntity.new()
	n.entity = -1; n.comp.position = api.type.Vec3f.new(ex, ey, ez)
	local s = api.type.SegmentAndEntity.new()
	s.entity = -2; s.type = 0
	s.comp.node0 = node; s.comp.node1 = -1
	s.comp.position0 = api.type.Vec3f.new(p.x, p.y, p.z); s.comp.position1 = api.type.Vec3f.new(ex, ey, ez)
	s.comp.tangent0 = api.type.Vec3f.new(tx, ty, tz); s.comp.tangent1 = api.type.Vec3f.new(tx, ty, tz)
	s.comp.type = 0; s.comp.typeIndex = -1
	s.comp.laneConfigs = tmpl.laneConfigs; s.comp.roadTemplate = tmplName; s.comp.roadStyle = tmpl.streetStyle
	s.comp.roadType = api.type.enum.RoadType.STREET
	prop.streetProposal.nodesToAdd = { n }
	prop.streetProposal.edgesToAdd = { s }
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, { error = "proposta: " .. tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "prolungamento rifiutato", detail = proposalErrors(res) } end
	-- nuovo capolinea: il nodo con un solo segmento tra quelli del nuovo tratto
	local newNode
	for _, e in ipairs(ents) do
		local b = comp(e, CT.BASE_EDGE)
		if b then
			for _, nn in ipairs({ b.node0, b.node1 }) do
				if nn ~= node and #each(api.engine.system.streetSystem.getNodeSegments(nn)) == 1 then newNode = nn end
			end
		end
	end
	return true, { node = newNode, ents = ents, x = ex, y = ey, z = ez, dx = dx, dy = dy }
end

-- Solo la costruzione del deposito, con il nodo d'ingresso nel punto (ex, ey, ez) e uscita verso (dx, dy).
function CC.placeDepotC(ex, ey, ez, dx, dy, localY, kind, name, ignoreErrors)
	-- (ex, ey): posizione voluta del nodo libero C; asse X locale = (dy, -dx), asse Y locale = (dx, dy)
	local lc = DEPOT_C[kind or "road"]
	local lx, ly = lc[1], lc[2]
	local tx, ty = ex - lx * dy - ly * dx, ey + lx * dx - ly * dy
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = DEPOT_CON[kind or "road"]
	-- deposito tram elettrificato quando i tram sono elettrici (parametro tramCatenary: 0 no, 1 si').
	-- Nota: ce.params va assegnato tutto insieme (il gioco copia la tabella, modifiche dopo vanno perse).
	local params = { year = CC.year(), seed = 0, modules = {} }
	-- i parametri delle costruzioni sono indici a partire da 1: tramCatenary 1 = No, 2 = Si'
	if kind == "tram" then params.tramCatenary = CC.tramElectric and 2 or 1 end
	ce.params = params
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(tx, ty, ez, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = name or "Deposito"
	prop.constructionsToAdd = { ce }
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignoreErrors == true, true)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	local out = { ents = ents }
	if not ok then out.error = "rifiutato"; out.detail = proposalErrors(res); return false, out end
	for _, x in ipairs(ents or {}) do
		local c = comp(x, CT.CONSTRUCTION)
		if c and #each(c.depots) > 0 then
			out.construction = x; out.depot = each(c.depots)[1]
			out.frozen = {}
			for _, fn in ipairs(each(c.frozenNodes)) do
				out.frozen[#out.frozen + 1] = { fn, #each(api.engine.system.streetSystem.getNodeSegments(fn)) }
			end
		end
	end
	return true, out
end

-- Verifica percorsi con il pathfinder. ATTENZIONE: usare solo NodeId validi forniti dal gioco
-- (terminali delle stazioni, inNodes/outNodes dei depositi): un NodeId inventato fa crashare il gioco.
function CC.stopNodeId(group)
	local sg = comp(group, CT.STATION_GROUP)
	local st = sg and each(sg.stations)[1]
	local s = st and comp(st, CT.STATION)
	local t = s and each(s.terminals)[1]
	return t and t.vehicleNodeId
end
function CC.depotNodes(depot)
	local d = comp(depot, CT.VEHICLE_DEPOT)
	if not d then return nil, nil end
	return each(d.outNodes)[1], each(d.inNodes)[1]
end
function CC.hasPath(a, b, modes)
	if not a or not b then return false end
	local ok, p = pcall(api.engine.util.pathfinding.findPathNodeToNode, { a }, { b }, modes)
	return ok and #each(p) > 0
end

-- ---------------------------------------------------------------- tram
-- Variante "con binari tram" (non elettrificata) di un modello di strada cittadina, se esiste.
-- Tram elettrici: dal modello che si comprera' (vedi CC.isElectricTram). CC.tramElectric lo imposta l'azione.
function CC.isElectricTram(modelId)
	local TM = api.type.enum.TransportMode
	local m = api.res.modelRep.get(modelId)
	local hasEngine, steam = false, false
	pcall(function()
		for _, tm in ipairs(each(m.metadata.transportVehicle.engineTransportModes)) do
			hasEngine = true
			if tm == TM.TRAM then steam = true end
		end
	end)
	return hasEngine and not steam
end

-- Variante tram di un template stradale. Strade "old": _tram e _tram_electrified; strade "new": solo
-- _tram_electrified. Con tram elettrici serve sempre la variante elettrificata.
function CC.tramTemplateFor(tmpl, electric)
	if not tmpl then return nil end
	if electric == nil then electric = CC.tramElectric end
	if tmpl:find("_tram_electrified", 1, true) then return tmpl end
	if tmpl:find("_tram", 1, true) and not electric then return tmpl end
	local base = tmpl:gsub("_tram_electrified", ""):gsub("_tram", ""):gsub("%.street_template$", "")
	local bases = { base }
	-- le strade "xsmall" non hanno la variante tram: uso quella "small" (un po' piu' larga)
	if base:find("_xsmall", 1, true) then bases[#bases + 1] = (base:gsub("_xsmall", "_small")) end
	local cands = {}
	for _, b in ipairs(bases) do
		if not electric then cands[#cands + 1] = b .. "_tram.street_template" end
		cands[#cands + 1] = b .. "_tram_electrified.street_template"
	end
	for _, t in ipairs(cands) do
		local ok, id = pcall(api.res.streetTemplateRep.find, t)
		if ok and id and id >= 0 then return t end
	end
	return nil
end

-- Segmenti di strada (entita') lungo il percorso tra due NodeId validi.
function CC.pathStreetEdges(a, b, modes)
	local out, seen = {}, {}
	local ok, p = pcall(api.engine.util.pathfinding.findPathNodeToNode, { a }, { b }, modes)
	if not ok then return nil end
	for _, x in ipairs(each(p)) do
		local eid = x[1]
		local e = eid and eid.entity
		if e and not seen[e] and comp(e, CT.BASE_EDGE_STREET) and not inConstruction(e) then
			seen[e] = true
			out[#out + 1] = e
		end
	end
	return out, #each(p)
end

-- Aggiunge i binari tram a un segmento di strada (stesso tracciato, modello "_tram").
function CC.addTramToEdge(e)
	local be = comp(e, CT.BASE_EDGE)
	if not be then return false, "segmento inesistente" end
	local cur = tostring(be.roadTemplate)
	local t = CC.tramTemplateFor(cur)
	if t == cur then return true, "gia' tram" end
	if not t then return false, "nessuna variante tram per " .. cur end
	local okP, prop = pcall(api.engine.util.proposal.replaceSegment, e, t)
	if not okP or not prop then return false, "replaceSegment: " .. tostring(prop) end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, "comando: " .. tostring(cmd) end
	local ok, res = CC.send(cmd)
	if not ok then return false, "rifiutato: " .. table.concat(proposalErrors(res).msg, "; ") end
	return true
end

-- Fa rigenerare al gioco le configurazioni (collegamenti tra corsie) dei nodi indicati.
function CC.refreshNodeConfigs(nodes)
	local cfg, seen = {}, {}
	for _, n in ipairs(nodes) do
		if not seen[n] and api.engine.entityExists(n) and comp(n, CT.BASE_NODE_CONFIG) then
			seen[n] = true
			cfg[#cfg + 1] = n
		end
	end
	if #cfg == 0 then return true, 0 end
	local p = api.type.SimpleProposal.new()
	p.streetProposal.nodeConfigsToRemove = cfg
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, nil, false, true)
	if not okc then return false, tostring(cmd) end
	local ok = CC.send(cmd)
	return ok, #cfg
end

-- Nodi dei segmenti con binari tram vicino a un punto.
function CC.tramNodesNear(x, y, r)
	local out = {}
	local list = api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE)
	for _, e in ipairs(each(list)) do
		local be = comp(e, CT.BASE_EDGE)
		if be and tostring(be.roadTemplate):find("_tram", 1, true) then
			out[#out + 1] = be.node0; out[#out + 1] = be.node1
		end
	end
	return out
end

-- Percorso sul grafo stradale (entita' nodo/segmento, nessun NodeId) da un nodo a un segmento:
-- Dijkstra sulla lunghezza dei segmenti. Ritorna la lista dei segmenti (compreso quello di arrivo) o nil.
function CC.graphPath(startNode, targetEdge, maxNodes)
	local tb = comp(targetEdge, CT.BASE_EDGE)
	if not tb then return nil end
	local goal = { [tb.node0] = true, [tb.node1] = true }
	local dist, prev, done = { [startNode] = 0 }, {}, {}
	local open = { startNode }
	local visited = 0
	while #open > 0 do
		local bi, bn = 1, open[1]
		for i = 2, #open do if dist[open[i]] < dist[bn] then bi, bn = i, open[i] end end
		table.remove(open, bi)
		if not done[bn] then
			done[bn] = true
			visited = visited + 1
			if goal[bn] then
				local out = { targetEdge }
				local n = bn
				while prev[n] do
					table.insert(out, 1, prev[n].edge)
					n = prev[n].node
				end
				return out
			end
			if visited > (maxNodes or 3000) then return nil end
			for _, e in ipairs(each(api.engine.system.streetSystem.getNodeSegments(bn))) do
				local be = comp(e, CT.BASE_EDGE)
				if be and comp(e, CT.BASE_EDGE_STREET) and not inConstruction(e) then
					local other = be.node0 == bn and be.node1 or be.node0
					local d = dist[bn] + edgeLen(be)
					if not done[other] and (not dist[other] or d < dist[other]) then
						dist[other] = d
						prev[other] = { node = bn, edge = e }
						open[#open + 1] = other
					end
				end
			end
		end
	end
	return nil
end

-- Segmento su cui sta la fermata di un gruppo di stazioni (l'entita' del suo nodo veicoli).
function CC.stopEdge(group)
	local nid = CC.stopNodeId(group)
	local e = nid and nid.entity
	if e and comp(e, CT.BASE_EDGE) then return e end
	return nil
end

-- ---------------------------------------------------------------- merci
-- Id delle merci in entrata e in uscita di un'industria.
function CC.industryCargo(ind)
	local ic = comp(ind, CT.INDUSTRY)
	if not ic or not ic.stockList or ic.stockList < 0 then return {}, {} end
	local ok, io = pcall(api.engine.util.stock.getInputsOutputsFromRules, ic.stockList)
	if not ok or not io then return {}, {} end
	local function list(v) local t = {} for _, x in ipairs(each(v)) do t[#t + 1] = x end return t end
	return list(io[1]), list(io[2])
end

-- Gruppo di stazioni stradali (camion) incluso nella costruzione di un'industria.
function CC.industryRoadStation(ind)
	local ic = comp(ind, CT.INDUSTRY)
	local con = ic and ic.construction
	local c = con and comp(con, CT.CONSTRUCTION)
	if not c then return nil end
	for _, st in ipairs(each(c.stations)) do
		local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
		if okG and g and g >= 0 then
			local okC, car = pcall(api.engine.system.stationGroupSystem.getCarriers, g, -1, -1)
			local road = false
			if okC and car then
				for _, x in ipairs(each(car[1])) do if x == api.type.enum.Carrier.ROAD then road = true end end
			end
			if road then return g end
		end
	end
	return nil
end

-- Capacita' di un modello per una merce (0 se non la trasporta).
function CC.modelCapacity(modelId, cargoId)
	local m = api.res.modelRep.get(modelId)
	local tv = m and m.metadata and m.metadata.transportVehicle
	if not tv then return 0 end
	local best = 0
	for _, cpt in ipairs(each(tv.compartments)) do
		for _, lc in ipairs(each(cpt.loadConfigs)) do
			local ce = lc.cargoEntry
			local has = false
			pcall(function() api.res.cargoTypeRep.forEachCargoType(ce.cargoTypeSet, function(id) if id == cargoId then has = true end end) end)
			if has and (ce.capacity or 0) > best then best = ce.capacity end
		end
	end
	return best
end

-- Veicolo disponibile quest'anno che trasporta la merce, con la capacita' maggiore.
function CC.pickModelForCargo(kind, cargoId)
	local year = CC.year()
	local best
	api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(name)
		if name:find("/" .. kind .. "/", 1, true) then
			local id = api.res.modelRep.find(name)
			local m = api.res.modelRep.get(id)
			local av = m and m.metadata and m.metadata.availability
			local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
			if from <= year and (to == 0 or to > year) then
				local cap = CC.modelCapacity(id, cargoId)
				if cap > 0 and (not best or cap > best.cap or (cap == best.cap and from > best.from)) then
					best = { id = id, name = name, cap = cap, from = from }
				end
			end
		end
	end)
	return best
end

function CC.cargoName(id)
	local ok, ct = pcall(api.res.cargoTypeRep.get, id)
	if ok and ct and ct.name then return ct.name end
	return tostring(id)
end

-- Diramazione: un tratto dritto di len metri perpendicolare a una strada, da un suo nodo intermedio.
-- Crea un capolinea dove mettere un deposito. Ritorna ok, { node = nuovo capolinea }
function CC.makeSpur(x, y, len, r)
	len = len or 30
	local tried = {}
	for _, c in ipairs(CC.streetEdgesNear(x, y, r or 500, 20)) do
		local be = comp(c.edge, CT.BASE_EDGE)
		for k, node in ipairs({ be.node0, be.node1 }) do
			local deg = #each(api.engine.system.streetSystem.getNodeSegments(node))
			if deg == 2 and not CC.comp(node, CT.BASE_NODE_CONFIG) or deg == 2 then
				local p = k == 1 and be.position0 or be.position1
				local t = k == 1 and be.tangent0 or be.tangent1
				local l = math.sqrt(t.x * t.x + t.y * t.y)
				local tx, ty = t.x / l, t.y / l
				for _, side in ipairs({ 1, -1 }) do
					local dx, dy = -ty * side, tx * side
					local ex, ey = p.x + dx * len, p.y + dy * len
					local tmplName = tostring(be.roadTemplate)
					local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(tmplName))
					local prop = api.type.SimpleProposal.new()
					local n = api.type.NodeAndEntity.new()
					n.entity = -1; n.comp.position = api.type.Vec3f.new(ex, ey, p.z)
					local sg = api.type.SegmentAndEntity.new()
					sg.entity = -2; sg.type = 0
					sg.comp.node0 = node; sg.comp.node1 = -1
					sg.comp.position0 = api.type.Vec3f.new(p.x, p.y, p.z); sg.comp.position1 = api.type.Vec3f.new(ex, ey, p.z)
					sg.comp.tangent0 = api.type.Vec3f.new(dx * len, dy * len, 0); sg.comp.tangent1 = api.type.Vec3f.new(dx * len, dy * len, 0)
					sg.comp.type = 0; sg.comp.typeIndex = -1
					sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = tmplName; sg.comp.roadStyle = tmpl.streetStyle
					sg.comp.roadType = api.type.enum.RoadType.STREET
					prop.streetProposal.nodesToAdd = { n }
					prop.streetProposal.edgesToAdd = { sg }
					if comp(node, CT.BASE_NODE_CONFIG) then prop.streetProposal.nodeConfigsToRemove = { node } end
					local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
					if okc then
						local ok, res, ents = CC.send(cmd)
						tried[#tried + 1] = { node = node, side = side, ok = ok }
						if ok then
							for _, e in ipairs(ents) do
								local b2 = comp(e, CT.BASE_EDGE)
								if b2 then
									for _, nn in ipairs({ b2.node0, b2.node1 }) do
										if nn ~= node and #each(api.engine.system.streetSystem.getNodeSegments(nn)) == 1 then
											return true, { node = nn, tried = tried }
										end
									end
								end
							end
						end
					end
					if #tried >= 8 then return false, { error = "nessuna diramazione possibile", tried = tried } end
				end
			end
		end
	end
	return false, { error = "nessuna strada vicina", tried = tried }
end

-- ---------------------------------------------------------------- ferrovia
local function terrainApi()
	return api.engine.terrain or (api.engine.util and api.engine.util.terrain)
end
function CC.heightAt(x, y)
	local t = terrainApi()
	local ok, h = pcall(t.getHeightAt, api.type.Vec2f.new(x, y))
	return ok and h or nil
end
function CC.onWater(x, y)
	local t = terrainApi()
	local ok, w = pcall(t.isOnWater, api.type.Vec2f.new(x, y))
	return ok and w == true
end

-- Tipo di ponte e galleria (indici nei repository del gioco), scelti in base all'anno.
-- Ponti: stone (campata 48 m), steel (90), concrete (84); gallerie tunnel_a/b/c per epoca.
function CC.bridgeType(year)
	year = year or CC.year()
	local name = CC.BRIDGE_NAME or (year < 1920 and "steel" or "concrete")
	local ok, id = pcall(api.res.bridgeTypeRep.find, "::/infrastructure/bridge/" .. name .. ".bridge")
	return ok and id or 1
end
function CC.tunnelType(year)
	local e = CC.railEra(year)
	local ok, id = pcall(api.res.tunnelTypeRep.find, "::/infrastructure/tunnel/tunnel_" .. e.era .. ".tunnel")
	return ok and id or 0
end

-- Impostazioni ferroviarie in base all'anno: epoca dei moduli (a/b/c), tipo di binario, linea aerea.
function CC.railEra(year)
	year = year or CC.year()
	local era = year < 1950 and "a" or (year < 1990 and "b" or "c")
	-- l'alta velocita' richiede raggi di curva molto ampi: le linee tra citta' vicine con colline e laghi
	-- vengono rifiutate ("Curvatura eccessiva"). Si usa lo standard (con catenaria); alta velocita' solo se richiesta.
	local track = year < 1925 and "simple" or ((CC.ALLOW_HIGH_SPEED and year >= 1990) and "high_speed" or "standard")
	local catenary = year >= 1915
	return { era = era, track = track, catenary = catenary, year = year }
end

-- CC.trackOverride: tipo di binario forzato (es. "standard" quando l'alta velocita' non e' consentita).
function CC.trackTemplate(e)
	e = e or CC.railEra()
	local tr = CC.trackOverride or e.track
	return "::/infrastructure/track/" .. tr .. "/" .. tr .. (e.catenary and "_catenary" or "") .. ".street_template"
end

-- Moduli di una stazione passeggeri con 1 binario da 160 m (schema copiato da una stazione costruita nel gioco).
-- Slot: 84xxxxx binari, 74xxxxx marciapiedi, 104xxxxx tettoie (4 pezzi da 40 m), 340xxxx edifici, 108xxxxx scale.
function CC.railStationModules(e, nTracks)
	e = e or CC.railEra()
	-- 2 binari: marciapiede (colonna 0), binario 1, binario 2, marciapiede (colonna 3); 2 terminal
	local trackCols, platCols = { 1 }, { 0 }
	if nTracks == 2 then trackCols, platCols = { 1, 2 }, { 0, 3 } end
	local M = "::/stations/rail/modular_station/"
	local T = "::/trainstation___/infrastructure/track/" .. e.track .. "/" .. e.track .. (e.catenary and "_catenary" or "") .. ".street_template"
	local era = "_era_" .. e.era
	local mods = {
		[3400005] = M .. "side_building_1" .. era .. ".module",
		[3400020] = M .. "main_building_1" .. era .. ".module",
		[3400035] = M .. "side_building_1" .. era .. ".module",
		[10800000] = M .. "addon_platform_passenger_stairs" .. era .. ".module",
	}
	for _, o in ipairs({ -10, 0, 10, 20 }) do
		for _, c in ipairs(trackCols) do mods[8400000 + c * 1000 + o] = T end
		for _, c in ipairs(platCols) do
			mods[7400000 + c * 1000 + o] = M .. "platform_passenger" .. era .. ".module"
			mods[10400000 + c * 1000 + o] = M .. "platform_passenger_roof" .. era .. ".module"
		end
	end
	local out = {}
	for k, v in pairs(mods) do out[k] = { name = v, variant = 0 } end
	return out
end

-- Stazione ferroviaria passeggeri (stazione modulare, modello 1900): binari lungo (dx, dy), centro (cx, cy).
-- lengthIdx/tracks sono gli indici dei parametri del gioco (verificati: tracks=1 -> 1 binario, length=3 -> 160 m).
-- Ritorna ok, { construction, station, group, ends = { {node, x, y, z, dx, dy}, ... } }
function CC.buildRailStation(cx, cy, dx, dy, opts)
	opts = opts or {}
	local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	local z = opts.z or CC.heightAt(cx, cy) or 0
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = "::/stations/rail/modular_station/modular_station.con"
	local nT = opts.tracks or 1
	ce.params = { year = CC.year(), seed = 0, modules = CC.railStationModules(nil, nT), tracks = nT, length = 3 }
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(cx, cy, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = opts.name or "Stazione"
	prop.constructionsToAdd = { ce }
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "stazione rifiutata", detail = proposalErrors(res) } end
	local con
	for _, e in ipairs(ents) do
		local c = comp(e, CT.CONSTRUCTION)
		if c and #each(c.stations) > 0 then con = e end
	end
	if not con then return false, { error = "stazione non trovata dopo la costruzione" } end
	local c = comp(con, CT.CONSTRUCTION)
	local st = each(c.stations)[1]
	local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
	local ends = CC.railStationEnds(con)
	if false then local seen = {}
	for _, fe in ipairs(each(c.frozenEdges)) do
		local be = comp(fe, CT.BASE_EDGE)
		for k, n in ipairs({ be.node0, be.node1 }) do
			if not seen[n] and #each(api.engine.system.streetSystem.getNodeSegments(n)) == 1 then
				seen[n] = true
				local p = k == 1 and be.position0 or be.position1
				local t = k == 1 and be.tangent0 or be.tangent1
				local tx, ty = t.x, t.y
				if k == 1 then tx, ty = -tx, -ty end
				local tl = math.sqrt(tx * tx + ty * ty)
				ends[#ends + 1] = { node = n, x = p.x, y = p.y, z = p.z, dx = tx / tl, dy = ty / tl }
			end
		end
	end end
	if opts.name and okG then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(g, opts.name)) end) end
	-- 2 binari: a ogni lato i due binari si uniscono in uno scambio (gola), che diventa l'estremo della stazione
	local edges = {}
	if nT == 2 and #ends == 4 then
		local sides = {}
		for _, en in ipairs(ends) do
			local key = (en.dx * dx + en.dy * dy) > 0 and "f" or "b"
			sides[key] = sides[key] or {}
			table.insert(sides[key], en)
		end
		local newEnds = {}
		for _, key in ipairs({ "f", "b" }) do
			local pair = sides[key]
			if not pair or #pair ~= 2 then return false, { error = "estremi della stazione a 2 binari non riconosciuti", construction = con } end
			-- scambio piu' lungo per i binari moderni (raggio minimo maggiore): simple 80 m, altri 160 m
			local thLen = CC.THROAT_LEN or ((CC.trackOverride or CC.railEra().track) == "simple" and 80 or 160)
			local okT, T = CC.buildThroat(pair[1], pair[2], thLen)
			if not okT then
				CC.removeConstruction(con)
				return false, { error = "scambio della stazione rifiutato: " .. tostring(T.error) }
			end
			newEnds[#newEnds + 1] = T.endInfo
			for _, e in ipairs(T.edges) do edges[#edges + 1] = e end
		end
		ends = newEnds
	end
	return true, { construction = con, station = st, group = okG and g or nil, ends = ends, edges = edges, tracks = nT }
end

-- Estremi liberi dei binari di una costruzione (stazione/deposito): nodo, posizione, direzione verso l'esterno.
function CC.railStationEnds(con)
	local c = comp(con, CT.CONSTRUCTION)
	local ends, seen = {}, {}
	for _, fe in ipairs(each(c and c.frozenEdges)) do
		local be = comp(fe, CT.BASE_EDGE)
		for k, n in ipairs({ be.node0, be.node1 }) do
			if not seen[n] and #each(api.engine.system.streetSystem.getNodeSegments(n)) == 1 then
				seen[n] = true
				local p = k == 1 and be.position0 or be.position1
				local t = k == 1 and be.tangent0 or be.tangent1
				local tx, ty = t.x, t.y
				if k == 1 then tx, ty = -tx, -ty end
				local tl = math.sqrt(tx * tx + ty * ty)
				ends[#ends + 1] = { node = n, x = p.x, y = p.y, z = p.z, dx = tx / tl, dy = ty / tl }
			end
		end
	end
	return ends
end

local TRACK_TMPL = nil  -- scelto in base all'anno (CC.trackTemplate)

-- Segmento di binario tra due nodi (id reali o negativi nuovi) con tangenti date.
local function trackSeg(id, n0, p0, t0, n1, p1, t1)
	local tmplName = CC.trackTemplate()
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(tmplName))
	local sg = api.type.SegmentAndEntity.new()
	sg.entity = id; sg.type = 1
	sg.comp.node0 = n0; sg.comp.node1 = n1
	sg.comp.position0 = p0; sg.comp.position1 = p1; sg.comp.tangent0 = t0; sg.comp.tangent1 = t1
	sg.comp.type = 0; sg.comp.typeIndex = -1
	sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = tmplName; sg.comp.roadStyle = tmpl.streetStyle
	sg.comp.roadType = api.type.enum.RoadType.TRACK
	return sg
end

-- Scambio: due estremi paralleli (stessa direzione d'uscita) si uniscono in un nodo P a L metri.
-- P sta sull'asse del primo binario. Ritorna { endInfo = estremo P, edges = segmenti creati }.
function CC.buildThroat(e1, e2, L)
	L = L or 60
	local dx, dy = e1.dx, e1.dy
	-- scambio "vero": il binario e1 prosegue dritto fino a P, e2 lo raggiunge con una curva a S
	local px, py = e1.x + dx * L, e1.y + dy * L
	local pz = e1.z
	local P = api.type.Vec3f.new(px, py, pz)
	local nd = api.type.NodeAndEntity.new()
	nd.entity = -1
	nd.comp.position = P
	local segs = {}
	for i, e in ipairs({ e1, e2 }) do
		local dist = math.sqrt((px - e.x) ^ 2 + (py - e.y) ^ 2)
		local T = api.type.Vec3f.new(dx * dist, dy * dist, pz - e.z)
		segs[i] = trackSeg(-1 - i, e.node, api.type.Vec3f.new(e.x, e.y, e.z), T, -1, P, T)
	end
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = { nd }
	prop.streetProposal.edgesToAdd = segs
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = table.concat(proposalErrors(res).msg, "; ") } end
	local node, edges = nil, {}
	for _, en in ipairs(ents or {}) do
		if comp(en, CT.BASE_EDGE) then edges[#edges + 1] = en end
	end
	-- il nodo dello scambio va cercato per posizione (tra le entita' restituite ci sono anche i nodi della stazione)
	local bd
	pcall(function()
		for _, n in ipairs(each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(px, py), 2, CT.BASE_NODE))) do
			local p = comp(n, CT.BASE_NODE).position
			local d = (p.x - px) ^ 2 + (p.y - py) ^ 2
			if not bd or d < bd then node, bd = n, d end
		end
	end)
	return true, { endInfo = { node = node, x = px, y = py, z = pz, dx = dx, dy = dy }, edges = edges }
end

-- Binario dritto tra due nodi esistenti, diviso in tratti di circa step metri; quota interpolata.
function CC.buildStraightTrack(n0, n1, step, ignoreErrors)
	step = step or 50
	local TRACK_TMPL = CC.trackTemplate()
	local a, b = comp(n0, CT.BASE_NODE), comp(n1, CT.BASE_NODE)
	if not a or not b then return false, { error = "nodo inesistente" } end
	local pa, pb = a.position, b.position
	local dx, dy, dz = pb.x - pa.x, pb.y - pa.y, pb.z - pa.z
	local L = math.sqrt(dx * dx + dy * dy)
	local n = math.max(1, math.ceil(L / step))
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(TRACK_TMPL))
	local prop = api.type.SimpleProposal.new()
	local nodes, segs = {}, {}
	local function nodeId(i)
		if i == 0 then return n0 end
		if i == n then return n1 end
		return -i
	end
	for i = 1, n - 1 do
		local nd = api.type.NodeAndEntity.new()
		nd.entity = -i
		nd.comp.position = api.type.Vec3f.new(pa.x + dx * i / n, pa.y + dy * i / n, pa.z + dz * i / n)
		nodes[#nodes + 1] = nd
	end
	local water = 0
	for i = 1, n do
		local x0, y0, z0 = pa.x + dx * (i - 1) / n, pa.y + dy * (i - 1) / n, pa.z + dz * (i - 1) / n
		local x1, y1, z1 = pa.x + dx * i / n, pa.y + dy * i / n, pa.z + dz * i / n
		if CC.onWater((x0 + x1) / 2, (y0 + y1) / 2) then water = water + 1 end
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = -(n + i)
		sg.type = 1
		sg.comp.node0 = nodeId(i - 1); sg.comp.node1 = nodeId(i)
		sg.comp.position0 = api.type.Vec3f.new(x0, y0, z0); sg.comp.position1 = api.type.Vec3f.new(x1, y1, z1)
		sg.comp.tangent0 = api.type.Vec3f.new(dx / n, dy / n, dz / n); sg.comp.tangent1 = api.type.Vec3f.new(dx / n, dy / n, dz / n)
		sg.comp.type = 0; sg.comp.typeIndex = -1
		sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = TRACK_TMPL; sg.comp.roadStyle = tmpl.streetStyle
		sg.comp.roadType = api.type.enum.RoadType.TRACK
		segs[#segs + 1] = sg
	end
	if water > 0 then return false, { error = "il tracciato attraversa l'acqua (" .. water .. " tratti): servono ponti" } end
	prop.streetProposal.nodesToAdd = nodes
	prop.streetProposal.edgesToAdd = segs
	local cfg = {}
	for _, n in ipairs({ n0, n1 }) do if comp(n, CT.BASE_NODE_CONFIG) then cfg[#cfg + 1] = n end end
	if #cfg > 0 then prop.streetProposal.nodeConfigsToRemove = cfg end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignoreErrors == true, true)
	if not okc then return false, { error = "proposta: " .. tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "binario rifiutato", detail = proposalErrors(res) } end
	return true, { segments = n, length = math.floor(L) }
end

-- Deposito ferroviario dietro un estremo libero (nodo, direzione verso l'esterno), a gap metri.
-- Geometria misurata: nodo libero del deposito a coordinate locali (-2.2, -70), binari lungo l'asse Y.
function CC.buildRailDepotAtEnd(endInfo, name, gap)
	gap = gap or 12
	local dx, dy = endInfo.dx, endInfo.dy
	local cx, cy = endInfo.x + dx * gap, endInfo.y + dy * gap
	-- il corpo del deposito sta verso +Y rispetto al nodo libero: asse Y locale = d (lontano dalla stazione)
	local Yx, Yy = dx, dy
	local Xx, Xy = Yy, -Yx
	local lx, ly = -2.2, -70
	local tx, ty = cx - lx * Xx - ly * Yx, cy - lx * Xy - ly * Yy
	local z = endInfo.z
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = "::/depots/rail/rail_depot.con"
	-- binari e catenaria come la linea. Indici da 1: trackType 1 simple, 2 standard, 3 high_speed; catenary 1 No, 2 Si'
	-- (verificato: con catenary = 2 i binari del deposito diventano "standard_catenary")
	local e = CC.railEra()
	ce.params = { year = CC.year(), seed = 0, modules = {},
		trackType = ({ simple = 1, standard = 2, high_speed = 3 })[CC.trackOverride or e.track] or 2, catenary = e.catenary and 2 or 1 }
	ce.transf = api.type.Mat4f.new(api.type.Vec4f.new(Xx, Xy, 0, 0), api.type.Vec4f.new(Yx, Yy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(tx, ty, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = name or "Deposito ferroviario"
	prop.constructionsToAdd = { ce }
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "deposito ferroviario rifiutato", detail = proposalErrors(res) } end
	local con, depot
	for _, e in ipairs(ents) do
		local c = comp(e, CT.CONSTRUCTION)
		if c and #each(c.depots) > 0 then con = e; depot = each(c.depots)[1] end
	end
	if not depot then return false, { error = "deposito non trovato dopo la costruzione" } end
	-- nodo libero del deposito piu' vicino all'estremo della stazione
	local best, bd
	for _, e in ipairs(CC.railStationEnds(con)) do
		local d = (e.x - endInfo.x) ^ 2 + (e.y - endInfo.y) ^ 2
		if not bd or d < bd then best, bd = e, d end
	end
	if not best then return false, { error = "estremo del deposito non trovato", depot = depot } end
	local okT, t = CC.buildStraightTrack(endInfo.node, best.node, 50, false)
	return okT, { depot = depot, construction = con, connect = okT, error = (not okT) and t.error or nil, detail = t.detail }
end

-- Treno: locomotiva + n carrozze (modelli piu' recenti disponibili), comprato e assegnato alla linea.
-- Locomotiva: veicolo "/train/" disponibile quest'anno, con motore e senza posti/merci; la piu' potente.
-- Senza linea aerea esclude le elettriche.
function CC.pickLocomotive(catenary)
	local year = CC.year()
	local best
	api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(name)
		if name:find("/train/", 1, true) then
			local id = api.res.modelRep.find(name)
			local m = api.res.modelRep.get(id)
			local md = m and m.metadata
			local av = md and md.availability
			local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
			if from <= year and (to == 0 or to > year) then
				local cap = 0
				pcall(function() for _, c in ipairs(each(md.transportVehicle.compartments)) do for _, lc in ipairs(each(c.loadConfigs)) do cap = cap + (lc.cargoEntry.capacity or 0) end end end)
				-- motore: engineTransportModes non vuoto; solo elettrica se non c'e' TRAIN tra i modi del motore
				local hasEngine, diesel = false, false
				pcall(function()
					for _, tm in ipairs(each(md.transportVehicle.engineTransportModes)) do
						hasEngine = true
						if tm == api.type.enum.TransportMode.TRAIN then diesel = true end
					end
				end)
				local electric = hasEngine and not diesel
				local power = hasEngine and from or 0
				if cap == 0 and hasEngine and (catenary or not electric) then
					-- le motrici dei treni bloccati (TGV, ETR...) hanno capacita' 0 ma non vanno con carrozze normali
					local head = name:find("_front", 1, true) or name:find("_back", 1, true) or name:find("_rear", 1, true)
						or name:find("_end", 1, true) or name:find("_middle", 1, true)
					local score = from - (head and 10000 or 0)
					if not best or score > best.score then best = { id = id, name = name, from = from, electric = electric, score = score } end
				end
			end
		end
	end)
	return best
end

function CC.buyTrain(depot, line, nCars)
	local loco = CC.pickLocomotive(CC.railEra().catenary)
	local car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true })
	if not loco or not car then return false, { error = "nessun treno/carrozza disponibile" } end
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local gt = comp(api.engine.util.getWorld(), CT.GAME_TIME)
	local function part(id)
		local p = vu.makePart(id, true, nil)
		p.purchaseTime = gt and math.floor(gt.gameTime) or 0
		local auto = {}
		for k = 1, math.max(1, #each(p.part.compartment2loadConfig)) do auto[k] = true end
		p.autoLoadConfig = auto
		return p
	end
	local vehicles, groups = { part(loco.id) }, { 1 }
	for _ = 1, nCars or 3 do vehicles[#vehicles + 1] = part(car.id); groups[#groups + 1] = 1 end
	local cfg = api.type.TransportVehicleConfig.new()
	cfg.vehicles = vehicles
	cfg.vehicleGroups = groups
	cfg.muFileNames = {}
	local ok, res = CC.send(api.cmd.makeVehicleBuyCmd(api.engine.util.getPlayer(), depot, cfg))
	local veh
	pcall(function() veh = res.resultVehicleEntity end)
	if not ok or not veh or veh < 0 then return false, { error = "acquisto treno fallito", loco = loco.name, car = car.name } end
	local ok2 = line and CC.send(api.cmd.makeVehicleSetLineCmd(veh, line, 0))
	return true, { vehicle = veh, loco = loco.name, car = car.name, assigned = ok2 }
end

-- Binario curvo (curva di Hermite) tra due estremi liberi: parte da a lungo la sua direzione d'uscita
-- e arriva in b lungo l'opposto della direzione d'uscita di b. Diviso in tratti di circa step metri.
-- Le strade attraversate vengono spezzate nel punto d'incrocio (passaggio a livello).
local function hermite(p0x, p0y, t0x, t0y, p1x, p1y, t1x, t1y)
	local function P(t)
		local t2, t3 = t * t, t * t * t
		local h00, h10, h01, h11 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
		return h00 * p0x + h10 * t0x + h01 * p1x + h11 * t1x, h00 * p0y + h10 * t0y + h01 * p1y + h11 * t1y
	end
	local function D(t)
		local t2 = t * t
		local d00, d10, d01, d11 = 6 * t2 - 6 * t, 3 * t2 - 4 * t + 1, -6 * t2 + 6 * t, 3 * t2 - 2 * t
		return d00 * p0x + d10 * t0x + d01 * p1x + d11 * t1x, d00 * p0y + d10 * t0y + d01 * p1y + d11 * t1y
	end
	return P, D
end

local function segIntersect(ax, ay, bx, by, cx, cy, dx, dy)
	local rx, ry, sx, sy = bx - ax, by - ay, dx - cx, dy - cy
	local den = rx * sy - ry * sx
	if math.abs(den) < 1e-9 then return nil end
	local u = ((cx - ax) * sy - (cy - ay) * sx) / den
	local v = ((cx - ax) * ry - (cy - ay) * rx) / den
	if u >= 0 and u <= 1 and v >= 0 and v <= 1 then return u, v end
	return nil
end

-- Spezza un segmento stradale al parametro s (0..1) aggiungendo un nodo: ritorna ok, nodo, x, y, z.
function CC.splitStreet(e, sv)
	local be = comp(e, CT.BASE_EDGE)
	local st = comp(e, CT.BASE_EDGE_STREET)
	if not be then return false, "segmento inesistente" end
	local p0, p1, t0, t1 = be.position0, be.position1, be.tangent0, be.tangent1
	local SP, SD = hermite(p0.x, p0.y, t0.x, t0.y, p1.x, p1.y, t1.x, t1.y)
	local qx, qy = SP(sv)
	local qdx, qdy = SD(sv)
	local zq = p0.z + (p1.z - p0.z) * sv
	local prop = api.type.SimpleProposal.new()
	local nd = api.type.NodeAndEntity.new()
	nd.entity = -1
	nd.comp.position = api.type.Vec3f.new(qx, qy, zq)
	local function half(id, n0, q0, tt0, n1, q1, tt1)
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = id; sg.type = 0
		sg.comp = comp(e, CT.BASE_EDGE)
		sg.comp.node0 = n0; sg.comp.node1 = n1
		sg.comp.position0 = q0; sg.comp.position1 = q1; sg.comp.tangent0 = tt0; sg.comp.tangent1 = tt1
		sg.comp.objects = {}
		sg.streetEdge = st
		return sg
	end
	local Q = api.type.Vec3f.new(qx, qy, zq)
	prop.streetProposal.nodesToAdd = { nd }
	prop.streetProposal.edgesToAdd = {
		half(-2, be.node0, api.type.Vec3f.new(p0.x, p0.y, p0.z), api.type.Vec3f.new(t0.x * sv, t0.y * sv, zq - p0.z), -1, Q,
			api.type.Vec3f.new(qdx * sv, qdy * sv, zq - p0.z)),
		half(-3, -1, Q, api.type.Vec3f.new(qdx * (1 - sv), qdy * (1 - sv), p1.z - zq), be.node1, api.type.Vec3f.new(p1.x, p1.y, p1.z),
			api.type.Vec3f.new(t1.x * (1 - sv), t1.y * (1 - sv), p1.z - zq)),
	}
	prop.streetProposal.edgesToRemove = { e }
	local cfg = {}
	for _, nn in ipairs({ be.node0, be.node1 }) do if comp(nn, CT.BASE_NODE_CONFIG) then cfg[#cfg + 1] = nn end end
	if #cfg > 0 then prop.streetProposal.nodeConfigsToRemove = cfg end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, tostring(cmd) end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, table.concat(proposalErrors(res).msg, "; ") end
	for _, en in ipairs(ents) do
		local bn = comp(en, CT.BASE_NODE)
		if bn and (bn.position.x - qx) ^ 2 + (bn.position.y - qy) ^ 2 < 1 then return true, en, qx, qy, zq end
	end
	return false, "nodo d'incrocio non trovato"
end

-- kf: "rigidita'" della curva (moltiplica le tangenti); valori diversi danno tracciati diversi.
function CC.buildCurvedTrack(a, b, step, ignoreErrors, kf)
	step = step or 60
	local TRACK_TMPL = CC.trackTemplate()
	local L = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
	local k = L * (kf or 0.9)
	local P, D = hermite(a.x, a.y, a.dx * k, a.dy * k, b.x, b.y, -b.dx * k, -b.dy * k)
	local function Z(t) return a.z + (b.z - a.z) * t end
	-- campionamento fine della curva
	local NS = 400
	local samples = {}
	local len = 0
	for i = 0, NS do
		local x, y = P(i / NS)
		if i > 0 then len = len + math.sqrt((x - samples[i].x) ^ 2 + (y - samples[i].y) ^ 2) end
		samples[i + 1] = { x = x, y = y, t = i / NS }
	end
	-- strade attraversate: segmenti stradali vicini al tracciato che intersecano la polilinea
	local crossings, seenE = {}, {}
	for i = 1, NS, 10 do
		local sp = samples[i]
		for _, e in ipairs(each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(sp.x, sp.y), 80, CT.BASE_EDGE))) do
			if not seenE[e] and comp(e, CT.BASE_EDGE_STREET) and not inConstruction(e) then
				seenE[e] = true
				local be = comp(e, CT.BASE_EDGE)
				for j = 1, NS do
					local s0, s1 = samples[j], samples[j + 1]
					local u, v = segIntersect(s0.x, s0.y, s1.x, s1.y, be.position0.x, be.position0.y, be.position1.x, be.position1.y)
					if u then
						-- angolo tra binario e strada (0-90 gradi): sotto MIN_CROSS_ANGLE il gioco non consente il passaggio a livello
						local tx, ty = s1.x - s0.x, s1.y - s0.y
						-- tangente vera della strada nel punto d'incrocio (le strade di campagna curvano)
						local _, RD = hermite(be.position0.x, be.position0.y, be.tangent0.x, be.tangent0.y, be.position1.x, be.position1.y, be.tangent1.x, be.tangent1.y)
						local rx, ry = RD(v)
						local cosA = math.abs(tx * rx + ty * ry) / math.max(1e-6, math.sqrt(tx * tx + ty * ty) * math.sqrt(rx * rx + ry * ry))
						local ang = math.deg(math.acos(math.min(1, cosA)))
						crossings[#crossings + 1] = { edge = e, t = s0.t + (s1.t - s0.t) * u, s = v, angle = ang }
						break
					end
				end
			end
		end
	end
	table.sort(crossings, function(p, q) return p.t < q.t end)
	-- ostacoli sul tracciato (industrie, campi, edifici, altre costruzioni): controllo PRIMA di toccare le strade
	do
		local hit
		local margin = 30 / math.max(len, 1)
		for i = 1, NS + 1 do
			local sp = samples[i]
			if sp.t > margin and sp.t < 1 - margin then
				for _, k in ipairs({ "CONSTRUCTION", "FIELD", "TOWN_BUILDING" }) do
					local okO, l = pcall(api.engine.util.octree.findEntitiesInCircle, api.type.Vec2f.new(sp.x, sp.y), 8, CT[k])
					if okO then
						for _, e in ipairs(each(l)) do
							-- le stazioni alle due estremita' (anche appena costruite) non sono ostacoli
							local own = false
							if k == "CONSTRUCTION" then
								local c = comp(e, CT.CONSTRUCTION)
								local fn = c and tostring(c.fileName) or ""
								local da = math.sqrt((sp.x - a.x) ^ 2 + (sp.y - a.y) ^ 2)
								local db = math.sqrt((sp.x - b.x) ^ 2 + (sp.y - b.y) ^ 2)
								if fn:find("station", 1, true) and (da < 250 or db < 250) then own = true end
							end
							if not own then hit = { k = k, e = e, x = math.floor(sp.x), y = math.floor(sp.y) } break end
						end
					end
					if hit then break end
				end
			end
			if hit then break end
		end
		if hit then
			return false, { error = "ostacolo sul tracciato (" .. hit.k .. " " .. tostring(hit.e) .. ")", retry = true, at = { hit.x, hit.y } }
		end
	end
	-- incroci troppo obliqui per un passaggio a livello (il gioco rifiuta gia' 31 gradi): sovrappasso su ponte
	-- ...e anche vicino a un incrocio stradale (nodo con 3+ strade): li' il passaggio a livello non e' consentito
	local n2s
	pcall(function() n2s = api.engine.system.streetSystem.getNode2SegmentMap() end)
	local function degree(n)
		local d = 0
		pcall(function() d = #each(n2s[n]) end)
		return d
	end
	-- quota "naturale" del binario in t: terreno, limitato dalla pendenza massima rispetto alle due estremita'
	local function estZ(t)
		local g = CC.RAIL_GRADE or 0.025
		local x, y = P(t)
		local h = CC.heightAt(x, y) or 0
		if CC.onWater(x, y) then h = math.max(h, 0) + (CC.BRIDGE_CLEARANCE or 8) end
		local lo = math.max(a.z - g * t * len, b.z - g * (1 - t) * len)
		local hi = math.min(a.z + g * t * len, b.z + g * (1 - t) * len)
		if lo > hi then return (lo + hi) / 2 end
		return math.max(lo, math.min(hi, h))
	end
	for _, c in ipairs(crossings) do
		local cbe0 = comp(c.edge, CT.BASE_EDGE)
		c.roadZ = cbe0 and (cbe0.position0.z + (cbe0.position1.z - cbe0.position0.z) * c.s) or 0
		c.estZ = estZ(c.t)
		if c.angle < (CC.MIN_CROSS_ANGLE or 45) then c.over = true; c.why = "obliquo" end
		local be = comp(c.edge, CT.BASE_EDGE)
		if be and not c.over then
			local elen = math.sqrt((be.position1.x - be.position0.x) ^ 2 + (be.position1.y - be.position0.y) ^ 2)
			if (c.s * elen < 12 and degree(be.node0) ~= 2) or ((1 - c.s) * elen < 12 and degree(be.node1) ~= 2) then
				c.over = true; c.why = "incrocio"
			end
		end
		-- strada molto piu' alta del binario: si passa sotto (galleria); molto piu' bassa: sopra (ponte)
		local tol = CC.LEVEL_TOL or 4
		if c.roadZ - c.estZ > tol then c.over = nil; c.under = true; c.why = "strada piu' alta"
		elseif c.estZ - c.roadZ > tol then c.over = true; c.why = c.why or "strada piu' bassa" end
	end
	-- parametri dei nodi del binario: regolari + incroci (tenendo almeno 15 m dagli altri nodi)
	local n = math.max(1, math.ceil(len / step))
	local ts = {}
	for i = 0, n do ts[#ts + 1] = { t = i / n } end
	local minDt = 15 / math.max(len, 1)
	for _, c in ipairs(crossings) do
		if c.t < minDt * 2 or c.t > 1 - minDt * 2 then
			return false, { error = "una strada passa troppo vicino alla stazione" }
		end
		-- stesso incrocio visto su due segmenti (es. una strada gia' spezzata li'): lo tengo una volta sola
		local dup = false
		for _, q in ipairs(ts) do if q.cross and math.abs(q.t - c.t) < minDt then dup = true end end
		if not dup then
			for i = #ts, 1, -1 do
				if not ts[i].cross and math.abs(ts[i].t - c.t) < minDt and ts[i].t > 0 and ts[i].t < 1 then table.remove(ts, i) end
			end
			ts[#ts + 1] = { t = c.t, cross = c }
		end
	end
	table.sort(ts, function(p, q) return p.t < q.t end)
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(TRACK_TMPL))
	local nodes, segs, water = {}, {}, 0
	local nextId = -1
	local function newId() local id = nextId; nextId = nextId - 1; return id end
	-- nodi
	-- prima fase: acqua? poi strade spezzate nei punti d'incrocio (passaggi a livello)
	for i = 1, #ts - 1 do
		local mx, my = P((ts[i].t + ts[i + 1].t) / 2)
		if CC.onWater(mx, my) then water = water + 1 end
	end
	-- l'acqua si attraversa con i ponti (vedi il profilo altimetrico piu' sotto)
	for _, q in ipairs(ts) do
		if q.cross and q.cross.over then
			-- sovrappasso: nodo nuovo sopra la strada, quota strada + franco; la strada non si tocca
			local cbe = comp(q.cross.edge, CT.BASE_EDGE)
			local rz = cbe and (cbe.position0.z + (cbe.position1.z - cbe.position0.z) * q.cross.s) or (CC.heightAt(P(q.t)) or 0)
			q.x, q.y = P(q.t)
			q.z, q.fixed, q.newNode = math.max(rz + (CC.OVERPASS_CLEARANCE or 8.5), q.cross.estZ or rz), true, true
		elseif q.cross and q.cross.under then
			-- sottopasso: nodo nuovo sotto la strada (in galleria)
			local cbe = comp(q.cross.edge, CT.BASE_EDGE)
			local rz = cbe and (cbe.position0.z + (cbe.position1.z - cbe.position0.z) * q.cross.s) or 0
			q.x, q.y = P(q.t)
			q.z, q.fixed, q.newNode = math.min(rz - (CC.UNDERPASS_CLEARANCE or 10), q.cross.estZ or rz), true, true
		elseif q.cross then
			-- se l'incrocio cade a meno di 5 m da un nodo della strada uso quel nodo (spezzare li' non e' consentito)
			local okS, nid, x, y, z
			local cbe = comp(q.cross.edge, CT.BASE_EDGE)
			if cbe then
				local elen = math.sqrt((cbe.position1.x - cbe.position0.x) ^ 2 + (cbe.position1.y - cbe.position0.y) ^ 2)
				local near
				if q.cross.s * elen < 5 then near = cbe.node0 elseif (1 - q.cross.s) * elen < 5 then near = cbe.node1 end
				if near then
					local bn = comp(near, CT.BASE_NODE)
					okS, nid, x, y, z = true, near, bn.position.x, bn.position.y, bn.position.z
				end
			end
			if not okS then okS, nid, x, y, z = CC.splitStreet(q.cross.edge, q.cross.s) end
			if not okS then
				local be = comp(q.cross.edge, CT.BASE_EDGE)
				local info = { edge = q.cross.edge, s = q.cross.s, tmpl = be and tostring(be.roadTemplate), t = q.t }
				pcall(function()
					info.len = math.sqrt((be.position1.x - be.position0.x) ^ 2 + (be.position1.y - be.position0.y) ^ 2)
					info.z0, info.z1 = be.position0.z, be.position1.z
					info.type = be.type
					info.con = api.engine.system.streetConnectorSystem.getConstructionEntityForEdge(q.cross.edge)
				end)
				return false, { error = "passaggio a livello non riuscito: " .. tostring(nid), detail = info }
			end
			q.id, q.x, q.y, q.z, q.fixed = nid, x, y, z, true
		end
	end
	ts[1].x, ts[1].y, ts[1].z, ts[1].fixed, ts[1].id = a.x, a.y, a.z, true, a.node
	ts[#ts].x, ts[#ts].y, ts[#ts].z, ts[#ts].fixed, ts[#ts].id = b.x, b.y, b.z, true, b.node
	-- estremo senza nodo (punto di passaggio di una deviazione): nodo nuovo
	if not a.node then ts[1].newNode = true end
	if not b.node then ts[#ts].newNode = true end
	-- primo e ultimo tratto in piano (niente cambi di pendenza sugli scambi delle stazioni)
	if #ts >= 4 then
		for _, pair in ipairs({ { 2, 1 }, { #ts - 1, #ts } }) do
			local q, e = ts[pair[1]], ts[pair[2]]
			if not q.fixed and not q.cross then
				q.x, q.y = P(q.t)
				q.z, q.fixed, q.newNode = e.z, true, true
			end
		end
	end
	-- anche ai lati dei passaggi a livello il binario resta in piano (quota della strada)
	for i, q in ipairs(ts) do
		if q.cross and not q.cross.over and not q.cross.under and q.id and q.id > 0 then
			for _, j in ipairs({ i - 1, i + 1 }) do
				local n = ts[j]
				if n and not n.fixed and not n.cross then
					n.x, n.y = P(n.t)
					n.z, n.fixed, n.newNode = q.z, true, true
				end
			end
		end
	end
	-- profilo altimetrico: segue il terreno con pendenza massima GRADE, fissi gli estremi e gli incroci.
	-- Dove il binario resta alto sul terreno o sopra l'acqua -> ponte; dove resta molto sotto -> galleria.
	local GRADE = CC.RAIL_GRADE or 0.025
	local sdist = { 0 }
	do
		local px, py = P(ts[1].t)
		for i = 2, #ts do
			local x, y = P(ts[i].t)
			sdist[i] = sdist[i - 1] + math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
			px, py = x, y
		end
	end
	local zp = {}
	for i, q in ipairs(ts) do
		if q.fixed then zp[i] = q.z
		else
			local x, y = P(q.t)
			local h = CC.heightAt(x, y) or 0
			if CC.onWater(x, y) then h = math.max(h, 0) + (CC.BRIDGE_CLEARANCE or 8) end
			zp[i] = h
		end
	end
	-- inviluppo dai punti fissi: la pendenza resta rispettabile fino al prossimo punto fisso
	for i, q in ipairs(ts) do
		if not q.fixed then
			local lo, hi = -math.huge, math.huge
			for j, f in ipairs(ts) do
				if f.fixed then
					local d = math.abs(sdist[i] - sdist[j]) * GRADE
					lo = math.max(lo, f.z - d); hi = math.min(hi, f.z + d)
				end
			end
			if lo > hi then lo, hi = (lo + hi) / 2, (lo + hi) / 2 end
			zp[i] = math.max(lo, math.min(hi, zp[i]))
		end
	end
	-- limitazione della pendenza tra nodi vicini (passate avanti e indietro)
	for _ = 1, 4 do
		for i = 2, #ts do
			if not ts[i].fixed then
				local d = (sdist[i] - sdist[i - 1]) * GRADE
				zp[i] = math.max(zp[i - 1] - d, math.min(zp[i - 1] + d, zp[i]))
			end
		end
		for i = #ts - 1, 1, -1 do
			if not ts[i].fixed then
				local d = (sdist[i + 1] - sdist[i]) * GRADE
				zp[i] = math.max(zp[i + 1] - d, math.min(zp[i + 1] + d, zp[i]))
			end
		end
	end
	for i, q in ipairs(ts) do if not q.fixed then q.z = zp[i] end end
	-- punti fissi troppo vicini per la pendenza (es. sovrappasso a ridosso di una stazione): tracciato da cambiare
	do
		local prev
		for i, q in ipairs(ts) do
			if q.fixed then
				if prev and math.abs(q.z - ts[prev].z) > (sdist[i] - sdist[prev]) * GRADE * 1.6 + 0.5 then
					local mx, my = P(q.t)
					local function kindOf(k)
						local qq = ts[k]
						if k == 1 or k == #ts then return qq.newNode and "passaggio" or "stazione" end
						if qq.cross and qq.cross.over then return "sovrappasso" end
						if qq.cross and qq.cross.under then return "sottopasso" end
						if qq.cross then return "passaggio a livello" end
						return "?"
					end
					return false, { error = "dislivello troppo forte tra " .. kindOf(prev) .. " e " .. kindOf(i) .. " ("
						.. math.floor(math.abs(q.z - ts[prev].z) * 10) / 10 .. " m in " .. math.floor(sdist[i] - sdist[prev]) .. " m; quote "
						.. math.floor(ts[prev].z * 10) / 10 .. " a " .. math.floor(ts[prev].x or 0) .. "," .. math.floor(ts[prev].y or 0) .. " e "
						.. math.floor(q.z * 10) / 10 .. " a " .. math.floor(q.x or 0) .. "," .. math.floor(q.y or 0) .. ")",
						retry = true, at = { math.floor(mx), math.floor(my) } }
				end
				prev = i
			end
		end
	end
	-- tipo di ogni tratto: 0 normale, 1 ponte, 2 galleria (mai sui tratti dei passaggi a livello)
	local bridgeIdx, tunnelIdx = CC.bridgeType(), CC.tunnelType()
	local segKind, nBridge, nTunnel = {}, 0, 0
	for i = 1, #ts - 1 do
		local wet, above, below = false, math.huge, -math.huge
		for _, f in ipairs({ 0.25, 0.5, 0.75 }) do
			local mx, my = P(ts[i].t + (ts[i + 1].t - ts[i].t) * f)
			local zz = ts[i].z + (ts[i + 1].z - ts[i].z) * f
			local h = CC.heightAt(mx, my) or 0
			if CC.onWater(mx, my) then wet = true end
			above = math.min(above, zz - h); below = math.max(below, h - zz)
		end
		local kind = 0
		if (ts[i].cross and ts[i].cross.under) or (ts[i + 1].cross and ts[i + 1].cross.under) then kind = 2
		elseif (ts[i].cross and ts[i].cross.over) or (ts[i + 1].cross and ts[i + 1].cross.over) then kind = 1
		elseif ts[i].cross or ts[i + 1].cross then kind = 0
		elseif wet or above > (CC.BRIDGE_MIN or 7) then kind = 1
		elseif below > (CC.TUNNEL_MIN or 14) then kind = 2 end
		segKind[i] = kind
		if kind == 1 then nBridge = nBridge + 1 elseif kind == 2 then nTunnel = nTunnel + 1 end
	end
	for i, q in ipairs(ts) do
		if not q.fixed or q.newNode then
			q.id = newId()
			if not q.newNode then q.x, q.y = P(q.t) end
			local nd = api.type.NodeAndEntity.new()
			nd.entity = q.id
			nd.comp.position = api.type.Vec3f.new(q.x, q.y, q.z)
			nodes[#nodes + 1] = nd
		end
	end
	-- segmenti del binario
	for i = 1, #ts - 1 do
		local q0, q1 = ts[i], ts[i + 1]
		local dt = q1.t - q0.t
		local d0x, d0y = D(q0.t); local d1x, d1y = D(q1.t)
		local dz = q1.z - q0.z
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = newId()
		sg.type = CC.CURVE_SEG_TYPE or 1      -- 1 binario (default); 0 strada (superstrade, bozza b4)
		sg.comp.node0 = q0.id; sg.comp.node1 = q1.id
		sg.comp.position0 = api.type.Vec3f.new(q0.x, q0.y, q0.z); sg.comp.position1 = api.type.Vec3f.new(q1.x, q1.y, q1.z)
		sg.comp.tangent0 = api.type.Vec3f.new(d0x * dt, d0y * dt, dz); sg.comp.tangent1 = api.type.Vec3f.new(d1x * dt, d1y * dt, dz)
		sg.comp.type = segKind[i] or 0
		sg.comp.typeIndex = (segKind[i] == 1 and bridgeIdx) or (segKind[i] == 2 and tunnelIdx) or -1
		sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = TRACK_TMPL; sg.comp.roadStyle = tmpl.streetStyle
		sg.comp.roadType = CC.CURVE_ROAD_TYPE or api.type.enum.RoadType.TRACK
		segs[#segs + 1] = sg
	end
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = nodes
	prop.streetProposal.edgesToAdd = segs
	-- i nodi d'incrocio hanno la configurazione della strada: la faccio rigenerare
	local cfgN = {}
	for _, q in ipairs(ts) do if q.cross and not q.cross.over and not q.cross.under and q.id > 0 and comp(q.id, CT.BASE_NODE_CONFIG) then cfgN[#cfgN + 1] = q.id end end
	-- anche gli estremi gia' collegati ad altri binari (es. scambio della stazione) vanno rigenerati
	for _, q in ipairs({ ts[1], ts[#ts] }) do
		if q.id and q.id > 0 and comp(q.id, CT.BASE_NODE_CONFIG) then cfgN[#cfgN + 1] = q.id end
	end
	if #cfgN > 0 then prop.streetProposal.nodeConfigsToRemove = cfgN end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignoreErrors == true, true)
	if not okc then return false, { error = "proposta: " .. tostring(cmd) } end
	local ok, res = CC.send(cmd)
	if not ok and ignoreErrors ~= true then
		-- collisioni solo con entita' "neutre" (es. fondale del lago sotto i piloni del ponte): costruisco lo stesso.
		-- Mai se tra le collisioni c'e' un edificio, una costruzione o un pezzo di strada/binario.
		local pe = proposalErrors(res)
		local neutral = pe.critical == false and #pe.msg == 0 and #pe.coll > 0
		for _, c in ipairs(pe.coll) do
			for _, k in ipairs({ "CONSTRUCTION", "TOWN_BUILDING", "BASE_EDGE", "BASE_NODE", "SIM_BUILDING", "INDUSTRY", "STATION" }) do
				local okc2, has = pcall(function() return CT[k] and comp(c, CT[k]) ~= nil end)
				if okc2 and has then neutral = false end
			end
		end
		if neutral then
			local okc3, cmd2 = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, true, true)
			if okc3 then ok, res = CC.send(cmd2) end
		end
	end
	if not ok then
		-- diagnosi: cerco (per bisezione, senza costruire) il primo tratto che rende la proposta non valida
		local bad = {}
		local nodeById = {}
		for _, nd in ipairs(nodes) do nodeById[nd.entity] = nd end
		local function checkUpTo(k)
			local p1 = api.type.SimpleProposal.new()
			local nn, ee, cf, seenN = {}, {}, {}, {}
			for i = 1, k do
				ee[#ee + 1] = segs[i]
				for _, id in ipairs({ ts[i].id, ts[i + 1].id }) do
					if not seenN[id] then
						seenN[id] = true
						if nodeById[id] then nn[#nn + 1] = nodeById[id]
						elseif id > 0 and comp(id, CT.BASE_NODE_CONFIG) then cf[#cf + 1] = id end
					end
				end
			end
			p1.streetProposal.nodesToAdd = nn
			p1.streetProposal.edgesToAdd = ee
			if #cf > 0 then p1.streetProposal.nodeConfigsToRemove = cf end
			local okP, pd = pcall(api.engine.util.proposal.makeProposalData, p1, nil)
			if not okP then return false, { "makeProposalData: " .. tostring(pd):sub(1, 100) } end
			local crit, msgs = false, {}
			pcall(function()
				crit = pd.errorState.critical
				for _, m in ipairs(each(pd.errorState.messages)) do msgs[#msgs + 1] = tostring(m) end
			end)
			return not crit, msgs
		end
		local lo, hi = 1, #ts - 1
		local okAll = checkUpTo(hi)
		if okAll then
			bad[1] = { note = "tutti i tratti validi insieme: il problema e' altrove (es. configurazioni dei nodi)" }
		else
			while lo < hi do
				local mid = math.floor((lo + hi) / 2)
				if checkUpTo(mid) then lo = mid + 1 else hi = mid end
			end
			local i = lo
			local q0, q1 = ts[i], ts[i + 1]
			local mx, my = P((q0.t + q1.t) / 2)
			local _, msgs = checkUpTo(i)
			-- estremo reale: il nodo e' davvero dove crediamo? e un tratto dritto da li' e' accettato?
			local endInfo
			if i == 1 or i == #ts - 1 then
				local q = (i == 1) and ts[1] or ts[#ts]
				local bn = q.id and q.id > 0 and comp(q.id, CT.BASE_NODE)
				endInfo = { node = q.id, newNode = q.newNode }
				pcall(function()
					endInfo.off = math.floor(math.sqrt((bn.position.x - q.x) ^ 2 + (bn.position.y - q.y) ^ 2) * 10) / 10
					endInfo.dz = math.floor((bn.position.z - q.z) * 10) / 10
					endInfo.deg = #each(api.engine.system.streetSystem.getNode2SegmentMap()[q.id])
				end)
			end
			bad[1] = { endInfo = endInfo, i = i, of = #ts - 1, kind = segKind[i], cross0 = q0.cross ~= nil, cross1 = q1.cross ~= nil,
				over = (q0.cross and q0.cross.over) or (q1.cross and q1.cross.over) or nil,
				z0 = math.floor(q0.z * 10) / 10, z1 = math.floor(q1.z * 10) / 10, ground = math.floor((CC.heightAt(mx, my) or 0) * 10) / 10,
				len = math.floor(sdist[i + 1] - sdist[i]), msg = msgs, x = math.floor(mx), y = math.floor(my) }
		end
		local pe = proposalErrors(res)
		local what = {}
		for _, c in ipairs(pe.coll) do
			if #what >= 4 then break end
			local d = tostring(c)
			pcall(function()
				local cc = comp(c, CT.CONSTRUCTION)
				if cc then d = d .. " " .. tostring(cc.fileName):match("([^/]+)%.con$")
				elseif comp(c, CT.FIELD) then d = d .. " campo"
				elseif comp(c, CT.INDUSTRY) then d = d .. " industria" end
			end)
			what[#what + 1] = d
		end
		return false, { error = "binario rifiutato" .. (#what > 0 and (" (collisione con " .. table.concat(what, ", ") .. ")") or ""),
			detail = pe, crossings = #crossings, bridges = nBridge, tunnels = nTunnel,
			segments = #ts - 1, badSegments = bad, retry = (#pe.coll > 0) }
	end
	local nOver = 0
	local nUnder = 0
	for _, q in ipairs(ts) do
		if q.cross and q.cross.over then nOver = nOver + 1 end
		if q.cross and q.cross.under then nUnder = nUnder + 1 end
	end
	-- segmenti creati (per poterli togliere se la linea poi non si completa)
	local newEdges = {}
	pcall(function()
		local _, _, ents = CC.lastSend()
		for _, en in ipairs(ents or {}) do if comp(en, CT.BASE_EDGE) then newEdges[#newEdges + 1] = en end end
	end)
	-- id del nodo creato all'estremo b, se era un punto di passaggio
	local endNode
	if not b.node then
		pcall(function()
			for _, n in ipairs(each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(b.x, b.y), 1.5, CT.BASE_NODE))) do endNode = n end
		end)
	end
	return true, { endNode = endNode, segments = #ts - 1, length = math.floor(len), crossings = #crossings - nOver - nUnder, overpasses = nOver, underpasses = nUnder, bridges = nBridge, tunnels = nTunnel, edges = newEdges }
end

-- Rimuove una costruzione costruita dalla mod (per pulire dopo un tentativo fallito).
function CC.removeConstruction(con)
	if not api.engine.entityExists(con) then return true end
	local okP, prop = pcall(api.engine.util.proposal.createProposalRemove, con, api.type.Context.new())
	if not okP or not prop then return false, "proposta di rimozione: " .. tostring(prop) end
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
	if not okc then return false, tostring(cmd) end
	local ok = CC.send(cmd)
	return ok and not api.engine.entityExists(con)
end

-- Toglie segmenti (binari) costruiti dalla mod; i nodi rimasti senza segmenti spariscono con loro.
function CC.removeEdges(list)
	local rm = {}
	for _, e in ipairs(list or {}) do if api.engine.entityExists(e) and comp(e, CT.BASE_EDGE) then rm[#rm + 1] = e end end
	if #rm == 0 then return true, 0 end
	-- nodi che resterebbero senza segmenti: vanno tolti anche loro
	local inSet = {}
	for _, e in ipairs(rm) do inSet[e] = true end
	local n2s
	pcall(function() n2s = api.engine.system.streetSystem.getNode2SegmentMap() end)
	local nodesRm, seenN = {}, {}
	for _, e in ipairs(rm) do
		local be = comp(e, CT.BASE_EDGE)
		for _, n in ipairs({ be.node0, be.node1 }) do
			if not seenN[n] then
				seenN[n] = true
				local alone = true
				pcall(function() for _, x in ipairs(each(n2s[n])) do if not inSet[x] then alone = false end end end)
				if alone then nodesRm[#nodesRm + 1] = n end
			end
		end
	end
	local p = api.type.SimpleProposal.new()
	p.streetProposal.edgesToRemove = rm
	p.streetProposal.nodesToRemove = nodesRm
	local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, nil, true, true)
	if not okc then return false, tostring(cmd) end
	local ok = CC.send(cmd)
	return ok, #rm
end

-- Percorso libero da edifici, industrie, campi e costruzioni lungo un segmento (x0,y0)->(x1,y1).
function CC.pathClear(x0, y0, x1, y1, radius)
	local L = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
	local n = math.max(1, math.ceil(L / 12))
	for i = 0, n do
		local x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
		for _, k in ipairs({ "CONSTRUCTION", "FIELD", "TOWN_BUILDING" }) do
			local okO, l = pcall(api.engine.util.octree.findEntitiesInCircle, api.type.Vec2f.new(x, y), radius or 10, CT[k])
			if okO and #each(l) > 0 then return false, each(l)[1] end
		end
	end
	return true
end

-- Nessuna strada entro 15 m lungo i prolungamenti dei binari (dx, dy) di una stazione centrata in (cx, cy).
function CC.railClearance(cx, cy, dx, dy, halfLen, beyond)
	for _, sgn in ipairs({ 1, -1 }) do
		for d = halfLen, halfLen + (beyond or 80), 15 do
			local x, y = cx + sgn * dx * d, cy + sgn * dy * d
			for _, e in ipairs(each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), 15, CT.BASE_EDGE))) do
				if comp(e, CT.BASE_EDGE_STREET) then return false end
			end
			if CC.onWater(x, y) then return false end
		end
	end
	return true
end
-- ===================================================================== fine CC
-- ===================================================================== azioni (lato simulazione)
-- Ogni azione riceve la tabella dell'azione (come scritta dal middleware) e ritorna una tabella
-- risultato { ok = true/false, ... }. Girano nel lato simulazione, dove i comandi sono sincroni.
local SIM_ACTIONS = {}

local function townCenter(id)
	local p = CC.posOf(id)
	if not p then error("entita' " .. tostring(id) .. " non trovata") end
	return p
end

local function playerStopsNear(x, y, r)
	local out = {}
	for g in pairs(CC.playerGroups()) do
		local p = CC.posOf(g)
		if p and (p.x - x) ^ 2 + (p.y - y) ^ 2 < r * r then out[#out + 1] = { x = p.x, y = p.y, group = g } end
	end
	return out
end

-- deposito stradale del giocatore raggiungibile dal nodo di una fermata (il piu' vicino), o nil
local function findRoadDepotFor(group, x, y, maxDist)
	local TM = api.type.enum.TransportMode
	local a = CC.stopNodeId(group)
	local best, bd
	for _, d in ipairs(CC.playerDepots()) do
		if d.file:find("road_depot", 1, true) and d.x then
			local dist = math.sqrt((d.x - x) ^ 2 + (d.y - y) ^ 2)
			if dist <= (maxDist or 2000) and (not bd or dist < bd) then
				local dOut = CC.depotNodes(d.depot)
				if CC.hasPath(dOut, a, { TM.BUS, TM.TRUCK }) then best, bd = d.depot, dist end
			end
		end
	end
	return best
end

local function ensureRoadDepot(group, x, y, name)
	local TM = api.type.enum.TransportMode
	local d = findRoadDepotFor(group, x, y, 2000)
	if d then return d, false end
	local ok, info = CC.buildDepotNear(x, y, "road", name, 1200)
	if not ok then error("deposito: " .. tostring(info.error)) end
	local dOut = CC.depotNodes(info.depot)
	if not CC.hasPath(dOut, CC.stopNodeId(group), { TM.BUS, TM.TRUCK }) then
		error("deposito costruito (" .. info.depot .. ") ma non collegato alle fermate")
	end
	return info.depot, true
end

local function lineInfo(line)
	local lc = CC.comp(line, api.type.ComponentType.LINE)
	if not lc then error("linea " .. tostring(line) .. " inesistente") end
	local groups = {}
	for _, s in ipairs(CC.each(lc.stops)) do groups[#groups + 1] = s.stationGroup end
	return groups
end

local function isCargoGroup(g)
	local sg = CC.comp(g, api.type.ComponentType.STATION_GROUP)
	local st = sg and CC.each(sg.stations)[1]
	local ok, c = pcall(api.engine.util.station.isStationOfType, st, true)
	return ok and c == true
end

-- fermata bus/tram vicino a una citta' o industria
SIM_ACTIONS.build_station = function(a)
	local kind = a.kind or "bus_stop"
	if kind ~= "bus_stop" and kind ~= "tram_stop" then
		return { ok = false, error = "tipo di stazione non ancora supportato: " .. kind .. " (per ora solo bus_stop)" }
	end
	local p = townCenter(a.near_entity_id)
	local avoid = playerStopsNear(p.x, p.y, 600)
	local ok, info = CC.buildStopNear(p.x, p.y, a.name or ((CC.nameOf(a.near_entity_id) or "") .. " fermata"),
		{ radius = a.radius or 350, avoid = avoid, spacing = 150 })
	if not ok then return { ok = false, error = info.error, tried = info.tried } end
	return { ok = true, station_id = info.group, x = math.floor(info.x), y = math.floor(info.y) }
end

SIM_ACTIONS.build_line = function(a)
	local ids = a.station_ids or {}
	if #ids < 2 then return { ok = false, error = "servono almeno 2 stazioni" } end
	for _, g in ipairs(ids) do
		if not CC.comp(g, api.type.ComponentType.STATION_GROUP) then
			return { ok = false, error = "id " .. tostring(g) .. " non e' un gruppo di stazioni" }
		end
	end
	local ok, info = CC.createLine(a.name or "Linea", ids)
	if not ok then return { ok = false, error = info.error } end
	return { ok = true, line_id = info.line }
end

SIM_ACTIONS.buy_and_assign_vehicles = function(a)
	local groups = lineInfo(a.line_id)
	if #groups == 0 then return { ok = false, error = "la linea non ha fermate" } end
	local cargo = isCargoGroup(groups[1])
	local p = CC.posOf(groups[1])
	local depot, built = a.depot_id, false
	if not depot then depot, built = ensureRoadDepot(groups[1], p.x, p.y, "Deposito " .. (CC.nameOf(a.line_id) or "")) end
	local model
	if a.model then
		local id = api.res.modelRep.find(a.model)
		if not id or id < 0 then return { ok = false, error = "modello non trovato: " .. a.model } end
		model = { id = id, name = a.model }
	else
		model = CC.pickModel(cargo and "truck" or "bus")
	end
	if not model then return { ok = false, error = "nessun veicolo disponibile quest'anno" } end
	local ok, info = CC.buyVehicles(depot, model.id, math.max(1, math.min(20, a.count or 1)), a.line_id)
	return { ok = ok and #info.errors == 0, vehicles = info.vehicles, errors = info.errors, depot_id = depot,
		depot_built = built, model = model.name }
end

-- linea bus completa in una citta': fermate, deposito, linea, veicoli
SIM_ACTIONS.build_bus_line = function(a)
	local TM = api.type.enum.TransportMode
	local town = a.town_id
	local c = townCenter(town)
	local tname = CC.nameOf(town) or "Citta'"
	local n = math.max(2, math.min(8, a.num_stops or 4))
	local radius = a.radius or 260
	local stops, avoid = {}, playerStopsNear(c.x, c.y, 800)
	local log = {}
	-- punti attorno al centro (anello), il primo al centro
	local pts = { { c.x, c.y } }
	for i = 1, n - 1 do
		local ang = (i - 1) * 2 * math.pi / (n - 1)
		pts[#pts + 1] = { c.x + math.cos(ang) * radius, c.y + math.sin(ang) * radius }
	end
	for i, pt in ipairs(pts) do
		local ok, info = CC.buildStopNear(pt[1], pt[2], tname .. " " .. i, { radius = 180, avoid = avoid, spacing = 140 })
		if ok and info.group then
			-- deve essere raggiungibile dalla fermata precedente
			local prev = stops[#stops]
			if prev and not CC.hasPath(CC.stopNodeId(prev.group), CC.stopNodeId(info.group), { TM.BUS }) then
				log[#log + 1] = "fermata " .. i .. " non raggiungibile, scartata dalla linea"
			else
				stops[#stops + 1] = { group = info.group, x = info.x, y = info.y }
			end
			avoid[#avoid + 1] = { x = info.x, y = info.y }
		else
			log[#log + 1] = "fermata " .. i .. ": " .. tostring(info.error)
		end
	end
	if #stops < 2 then return { ok = false, error = "costruite meno di 2 fermate utilizzabili", log = log } end
	local groups = {}
	for _, s in ipairs(stops) do groups[#groups + 1] = s.group end
	local depot, built = ensureRoadDepot(groups[1], c.x, c.y, "Deposito " .. tname)
	local okL, li = CC.createLine(a.name or ("Bus " .. tname), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, depot_id = depot } end
	local model = CC.pickModel("bus", nil, { passengers = true })
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(10, a.num_vehicles or 2)), li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, depot_built = built,
		vehicles = v.vehicles, model = model.name, errors = v.errors, log = log }
end

-- stessa disposizione delle fermate di build_bus_line: la prima al centro, le altre ad anello
local function ringStops(c, tname, n, radius, modes)
	local stops, avoid, log = {}, playerStopsNear(c.x, c.y, 800), {}
	local pts = { { c.x, c.y } }
	for i = 1, n - 1 do
		local ang = (i - 1) * 2 * math.pi / (n - 1)
		pts[#pts + 1] = { c.x + math.cos(ang) * radius, c.y + math.sin(ang) * radius }
	end
	for i, pt in ipairs(pts) do
		local ok, info = CC.buildStopNear(pt[1], pt[2], tname .. " " .. i, { radius = 180, avoid = avoid, spacing = 140 })
		if ok and info.group then
			local prev = stops[#stops]
			if prev and not CC.hasPath(CC.stopNodeId(prev.group), CC.stopNodeId(info.group), modes) then
				log[#log + 1] = "fermata " .. i .. " non raggiungibile, scartata dalla linea"
			else
				stops[#stops + 1] = { group = info.group, x = info.x, y = info.y }
			end
			avoid[#avoid + 1] = { x = info.x, y = info.y }
		else
			log[#log + 1] = "fermata " .. i .. ": " .. tostring(info.error)
		end
	end
	return stops, log
end

-- binari tram lungo il percorso stradale da a a b (NodeId); ritorna numero segmenti convertiti, errori
local function tramAlong(a, b, log)
	local TM = api.type.enum.TransportMode
	local edges = CC.pathStreetEdges(a, b, { TM.BUS })
	if not edges then log[#log + 1] = "percorso non trovato"; return 0 end
	local n = 0
	for _, e in ipairs(edges) do
		local ok, err = CC.addTramToEdge(e)
		if ok then n = n + 1 else log[#log + 1] = "binari su " .. e .. ": " .. tostring(err) end
	end
	return n
end

-- linea tram completa: fermate, binari sulle strade del percorso (ad anello), deposito tram, linea, tram
SIM_ACTIONS.build_tram_line = function(a)
	local TM = api.type.enum.TransportMode
	local town = a.town_id
	local c = townCenter(town)
	local tname = CC.nameOf(town) or "Citta'"
	local n = math.max(2, math.min(8, a.num_stops or 4))
	-- il modello di tram decide se i binari vanno elettrificati
	local model = CC.pickModel("tram", { "cargo", "wagon" }, { passengers = true })
	if not model then return { ok = false, error = "nessun tram disponibile quest'anno" } end
	CC.tramElectric = CC.isElectricTram(model.id)
	local stops, log = ringStops(c, tname .. " tram", n, a.radius or 240, { TM.BUS })
	if #stops < 2 then return { ok = false, error = "costruite meno di 2 fermate utilizzabili", log = log } end
	local groups = {}
	for _, s in ipairs(stops) do groups[#groups + 1] = s.group end
	-- binari: tra fermate vicine nell'anello, in tutti e due i versi (i percorsi del bus possono essere diversi)
	local converted = 0
	for i = 1, #groups do
		local g1, g2 = groups[i], groups[i % #groups + 1]
		converted = converted + tramAlong(CC.stopNodeId(g1), CC.stopNodeId(g2), log)
		converted = converted + tramAlong(CC.stopNodeId(g2), CC.stopNodeId(g1), log)
	end
	-- deposito tram: uno esistente collegato, altrimenti nuovo
	local depot, built
	for _, d in ipairs(CC.playerDepots()) do
		if d.file:find("tram_depot", 1, true) and d.x and (d.x - c.x) ^ 2 + (d.y - c.y) ^ 2 < 2000 ^ 2 then
			local dOut = CC.depotNodes(d.depot)
			if CC.hasPath(dOut, CC.stopNodeId(groups[1]), { CC.tramElectric and TM.ELECTRIC_TRAM or TM.TRAM }) then depot = d.depot end
		end
	end
	if not depot then
		local okD, D = CC.buildDepotNear(stops[1].x, stops[1].y, "tram", "Deposito tram " .. tname, 900)
		if not okD then return { ok = false, error = "deposito tram: " .. tostring(D.error), stations = groups, log = log } end
		if not D.connected then return { ok = false, error = "deposito tram costruito ma non collegato alla strada", depot_id = D.depot, log = log } end
		depot, built = D.depot, true
		-- binari dal capolinea del deposito fino alla fermata piu' vicina (percorso sul grafo stradale:
		-- il deposito tram ha uscite solo tram, quindi il pathfinder in modalita' bus non lo vede)
		local bestPath
		for _, g in ipairs(groups) do
			local se = CC.stopEdge(g)
			local path = se and CC.graphPath(D.node, se, 3000)
			if path and (not bestPath or #path < #bestPath) then bestPath = path end
		end
		if bestPath then
			for _, e in ipairs(bestPath) do
				local ok, err = CC.addTramToEdge(e)
				if ok then converted = converted + 1 else log[#log + 1] = "binari deposito su " .. e .. ": " .. tostring(err) end
			end
		else
			log[#log + 1] = "nessun percorso stradale dal deposito alle fermate"
		end
	end
	-- verifica finale con il pathfinder in modalita' tram: i tram non fanno inversione, quindi cerco
	-- l'anello piu' lungo di fermate percorribile nel verso giusto (ricerca completa, al massimo 8 fermate)
	local pc = CC.posOf(groups[1])
	CC.refreshNodeConfigs(CC.tramNodesNear(pc.x, pc.y, 1500))
	local n = #groups
	local reach = {}
	for i = 1, n do
		reach[i] = {}
		for j = 1, n do
			reach[i][j] = i ~= j and CC.hasPath(CC.stopNodeId(groups[i]), CC.stopNodeId(groups[j]), { CC.tramElectric and TM.ELECTRIC_TRAM or TM.TRAM })
		end
	end
	local best = {}
	local function dfs(path, used)
		local last = path[#path]
		if #path >= 2 and reach[last][path[1]] and #path > #best then
			best = {}
			for k, v in ipairs(path) do best[k] = v end
		end
		for j = 1, n do
			if not used[j] and reach[last][j] then
				used[j] = true; path[#path + 1] = j
				dfs(path, used)
				path[#path] = nil; used[j] = false
			end
		end
	end
	for start = 1, n do dfs({ start }, { [start] = true }) end
	if #best < 2 then
		return { ok = false, error = "nessun anello di fermate percorribile in tram (i tram non fanno inversione)",
			stations = groups, depot_id = depot, log = log }
	end
	local chosen = {}
	for k, idx in ipairs(best) do chosen[k] = groups[idx] end
	if #chosen < n then log[#log + 1] = "usate " .. #chosen .. " fermate su " .. n .. " (le altre non sono in un anello percorribile)" end
	groups = chosen
	-- il deposito deve raggiungere almeno una fermata dell'anello: la linea parte da quella
	local dOut = CC.depotNodes(depot)
	local startIdx
	for k, g in ipairs(groups) do
		if CC.hasPath(dOut, CC.stopNodeId(g), { CC.tramElectric and TM.ELECTRIC_TRAM or TM.TRAM }) then startIdx = k; break end
	end
	if not startIdx then
		return { ok = false, error = "il deposito tram non raggiunge nessuna fermata", stations = groups, depot_id = depot, log = log }
	end
	if startIdx > 1 then
		local rot = {}
		for k = 0, #groups - 1 do rot[#rot + 1] = groups[(startIdx - 1 + k) % #groups + 1] end
		groups = rot
	end
	local checks = { depot = true, legs = #groups }
	local okL, li = CC.createLine(a.name or ("Tram " .. tname), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, depot_id = depot, checks = checks, log = log } end
	-- tutti i tram partono verso la prima fermata (quella raggiungibile dal deposito)
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(10, a.num_vehicles or 2)), li.line, 0)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, depot_built = built,
		tracks = converted, checks = checks, vehicles = v.vehicles, model = model.name, electric = CC.tramElectric, errors = v.errors, log = log }
end

-- Trasporto merci su strada da un'industria a un'altra industria o a una citta'.
SIM_ACTIONS.connect_industry_to_city = function(a)
	local TM = api.type.enum.TransportMode
	if (a.transport or "truck") ~= "truck" then
		return { ok = false, error = "per ora le merci sono supportate solo su strada (transport = truck)" }
	end
	local ind, target = a.industry_id, a.target_id
	if not CC.comp(ind, api.type.ComponentType.INDUSTRY) then return { ok = false, error = tostring(ind) .. " non e' un'industria" } end
	local src = CC.industryRoadStation(ind)
	if not src then return { ok = false, error = "l'industria non ha una stazione per camion" } end
	local _, outs = CC.industryCargo(ind)
	if #outs == 0 then return { ok = false, error = "l'industria non produce merci" } end
	local log = {}
	local dst, cargo
	if CC.comp(target, api.type.ComponentType.INDUSTRY) then
		dst = CC.industryRoadStation(target)
		if not dst then return { ok = false, error = "l'industria di destinazione non ha una stazione per camion" } end
		local ins = CC.industryCargo(target)
		for _, o in ipairs(outs) do
			for _, i in ipairs(ins) do if o == i then cargo = o end end
		end
		if not cargo then return { ok = false, error = "la destinazione non usa le merci prodotte da questa industria" } end
	elseif CC.comp(target, api.type.ComponentType.TOWN) then
		-- la citta' deve accettare almeno una delle merci prodotte
		local accepted = {}
		pcall(function()
			for _, list in pairs(api.engine.util.town.getLandUse2CargoTypes()) do
				for _, id in ipairs(CC.each(list)) do accepted[id] = true end
			end
		end)
		for _, o in ipairs(outs) do if accepted[o] and not cargo then cargo = o end end
		if not cargo then
			local names = {}
			for _, o in ipairs(outs) do names[#names + 1] = CC.cargoName(o) end
			return { ok = false, error = "le citta' non accettano " .. table.concat(names, ", ") ..
				": va portato prima a un'industria che le lavora" }
		end
		-- citta': fermata su strada (le fermate piccole raccolgono anche merci) vicino al centro
		local c = townCenter(target)
		local okS, st = CC.buildStopNear(c.x, c.y, (CC.nameOf(target) or "Citta'") .. " merci",
			{ radius = 350, avoid = playerStopsNear(c.x, c.y, 600), spacing = 120 })
		if not okS then return { ok = false, error = "fermata merci in citta': " .. tostring(st.error) } end
		dst = st.group
		log[#log + 1] = "fermata merci costruita in citta' (" .. dst .. ")"
	else
		return { ok = false, error = tostring(target) .. " non e' ne' una citta' ne' un'industria" }
	end
	local a1, b1 = CC.stopNodeId(src), CC.stopNodeId(dst)
	if not CC.hasPath(a1, b1, { TM.TRUCK }) or not CC.hasPath(b1, a1, { TM.TRUCK }) then
		return { ok = false, error = "non c'e' un collegamento stradale tra origine e destinazione (andata e ritorno)", stations = { src, dst }, log = log }
	end
	local model = CC.pickModelForCargo("truck", cargo)
	if not model then return { ok = false, error = "nessun camion disponibile per " .. CC.cargoName(cargo) } end
	local p = CC.posOf(src)
	local depot, built = ensureRoadDepot(src, p.x, p.y, "Deposito " .. (CC.nameOf(ind) or ""))
	local okL, li = CC.createLine(a.name or (CC.cargoName(cargo) .. ": " .. (CC.nameOf(ind) or "") .. " - " .. (CC.nameOf(target) or "")), { src, dst })
	if not okL then return { ok = false, error = li.error } end
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(20, a.num_vehicles or 2)), li.line, 0)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = { src, dst }, cargo = CC.cargoName(cargo),
		depot_id = depot, depot_built = built, model = model.name, capacity = model.cap, vehicles = v.vehicles, errors = v.errors, log = log }
end

-- Linea ferroviaria passeggeri tra 2 o piu' citta' (in ordine): stazioni, binari, deposito, linea, treni.
-- Binario da ea a eb passando per un punto laterale W (a 400/800 m dalla retta, a destra o a sinistra).
local function railDetour(ea, eb, log, label)
	local mx, my = (ea.x + eb.x) / 2, (ea.y + eb.y) / 2
	local L = math.sqrt((eb.x - ea.x) ^ 2 + (eb.y - ea.y) ^ 2)
	local ux, uy = (eb.x - ea.x) / L, (eb.y - ea.y) / L
	local px, py = -uy, ux
	local last = { error = "nessuna deviazione possibile", retry = true }
	for _, off in ipairs({ 400, -400, 800, -800, 1200, -1200 }) do
		local wx, wy = mx + px * off, my + py * off
		if not CC.onWater(wx, wy) then
			local g = CC.RAIL_GRADE or 0.025
			local d1 = math.sqrt((wx - ea.x) ^ 2 + (wy - ea.y) ^ 2)
			local d2 = math.sqrt((eb.x - wx) ^ 2 + (eb.y - wy) ^ 2)
			local wz = CC.heightAt(wx, wy) or ((ea.z + eb.z) / 2)
			wz = math.max(ea.z - g * d1 * 0.8, eb.z - g * d2 * 0.8, math.min(ea.z + g * d1 * 0.8, eb.z + g * d2 * 0.8, wz))
			-- direzione nel punto W: parallela alla retta ea-eb
			local W = { x = wx, y = wy, z = wz, dx = -ux, dy = -uy }
			for _, kf in ipairs({ 0.7, 0.45 }) do
				local ok1, i1 = CC.buildCurvedTrack(ea, W, 60, false, kf)
				if ok1 and i1.endNode then
					local W2 = { x = wx, y = wy, z = wz, dx = ux, dy = uy, node = i1.endNode }
					local ok2, i2 = CC.buildCurvedTrack(W2, eb, 60, false, kf)
					if ok2 then
						local edges = {}
						for _, e in ipairs(i1.edges or {}) do edges[#edges + 1] = e end
						for _, e in ipairs(i2.edges or {}) do edges[#edges + 1] = e end
						log[#log + 1] = label .. ": deviazione laterale di " .. math.abs(off) .. " m"
						return true, { length = i1.length + i2.length, bridges = (i1.bridges or 0) + (i2.bridges or 0),
							tunnels = (i1.tunnels or 0) + (i2.tunnels or 0), crossings = (i1.crossings or 0) + (i2.crossings or 0),
							overpasses = (i1.overpasses or 0) + (i2.overpasses or 0), underpasses = (i1.underpasses or 0) + (i2.underpasses or 0), edges = edges }
					end
					CC.removeEdges(i1.edges)
					last = i2
					log[#log + 1] = label .. ": deviazione " .. off .. " m (kf " .. kf .. "), seconda meta': " .. tostring(i2.error)
				else
					last = i1
					log[#log + 1] = label .. ": deviazione " .. off .. " m (kf " .. kf .. "), prima meta': " .. tostring(i1.error)
				end
			end
		end
	end
	return false, last
end

local function buildRailLine(a, built_, builtEdges_)
	local TM = api.type.enum.TransportMode
	local towns = a.town_ids or {}
	if #towns < 2 then return { ok = false, error = "servono almeno 2 citta'" } end
	local C = {}
	for i, t in ipairs(towns) do C[i] = townCenter(t) end
	local log, stations = {}, {}
	-- direzione dei binari di ogni stazione: verso la citta' successiva (media con la precedente per quelle in mezzo)
	local function unit(x, y) local l = math.sqrt(x * x + y * y); return x / l, y / l end
	for i, t in ipairs(towns) do
		local dx, dy
		if i == 1 then dx, dy = unit(C[2].x - C[1].x, C[2].y - C[1].y)
		elseif i == #towns then dx, dy = unit(C[i].x - C[i - 1].x, C[i].y - C[i - 1].y)
		else
			local ax, ay = unit(C[i].x - C[i - 1].x, C[i].y - C[i - 1].y)
			local bx, by = unit(C[i + 1].x - C[i].x, C[i + 1].y - C[i].y)
			dx, dy = unit(ax + bx, ay + by)
		end
		-- posti candidati: fuori dal centro, prima lungo la direzione della linea, poi ai lati
		local tname = CC.nameOf(t) or ("citta' " .. i)
		local built
		-- quota di riferimento: il centro della citta'; prima posti piani e alla stessa quota, poi si allarga
		local zRef = CC.heightAt(C[i].x, C[i].y) or C[i].z or 0
		-- passate: (dislivello massimo dal centro, metri senza strade oltre gli estremi)
		for _, pass in ipairs({ { 12, 250 }, { 30, 250 }, { 12, 140 }, { 30, 140 }, { 1e9, 140 } }) do
		local maxDz, beyond = pass[1], pass[2]
		for _, R in ipairs({ 350, 500, 650, 800, 1000 }) do
			for _, ang in ipairs({ 90, -90, 60, -60, 120, -120, 30, -30, 150, -150, 0, 180 }) do
				local r = math.rad(ang)
				local ox, oy = dx * math.cos(r) - dy * math.sin(r), dx * math.sin(r) + dy * math.cos(r)
				local cx, cy = C[i].x + ox * R, C[i].y + oy * R
				local hC = CC.heightAt(cx, cy) or zRef
				local hA = CC.heightAt(cx - dx * 90, cy - dy * 90) or hC
				local hB = CC.heightAt(cx + dx * 90, cy + dy * 90) or hC
				local flatOk = math.abs(hC - zRef) <= maxDz and (maxDz > 1e8 or math.abs(hA - hB) <= 6)
				local exitsOk = true
				for _, j in ipairs({ i - 1, i + 1 }) do
					if C[j] then
						local s = ((C[j].x - cx) * dx + (C[j].y - cy) * dy) >= 0 and 1 or -1
						local ex, ey = cx + s * dx * 90, cy + s * dy * 90  -- estremo dei binari; lo scambio arriva fino a +160 m
						local tx, ty = C[j].x - ex, C[j].y - ey
						local tl = math.sqrt(tx * tx + ty * ty)
						-- primi 400 m: un po' verso la citta' vicina e un po' dritti, come il binario che uscira'
						local mx, my = ex + (s * dx * 0.6 + tx / tl * 0.4) * 400, ey + (s * dy * 0.6 + ty / tl * 0.4) * 400
						if not CC.pathClear(ex, ey, mx, my, 10) then exitsOk = false end
					end
				end
				if flatOk and exitsOk and not CC.onWater(cx, cy) and CC.railClearance(cx, cy, dx, dy, 100, beyond) then
					local ok, info = CC.buildRailStation(cx, cy, dx, dy, { name = tname .. " stazione", tracks = CC.STATION_TRACKS or 2 })
					if ok and info.group and #info.ends == 2 then built = info; break end
				end
			end
			if built then break end
		end
			if built then break end
		end
		if not built then return { ok = false, error = "non trovo spazio per la stazione di " .. tname, stations = stations, log = log } end
		built.town = t
		stations[i] = built
		built_[#built_ + 1] = built.construction
		for _, e in ipairs(built.edges or {}) do builtEdges_[#builtEdges_ + 1] = e end
	end
	-- binari tra stazioni consecutive: dall'estremo rivolto verso la successiva
	local function endToward(st, x, y)
		local best, bv
		for _, e in ipairs(st.ends) do
			local v = (x - e.x) * e.dx + (y - e.y) * e.dy
			if not bv or v > bv then best, bv = e, v end
		end
		return best
	end
	local used = {}
	for i = 1, #stations - 1 do
		local sa, sb = stations[i], stations[i + 1]
		local pa, pb = CC.posOf(sb.group), CC.posOf(sa.group)
		local ea, eb = endToward(sa, pa.x, pa.y), endToward(sb, pb.x, pb.y)
		if used[ea.node] or used[eb.node] then return { ok = false, error = "orientamento delle stazioni non compatibile", log = log } end
		used[ea.node] = true; used[eb.node] = true
		-- piu' forme di curva; se nessuna va, deviazione laterale attraverso un punto di passaggio
		local ok, info
		for _, kf in ipairs({ 0.9, 0.5, 1.4, 0.3 }) do
			ok, info = CC.buildCurvedTrack(ea, eb, 60, false, kf)
			if ok or not info.retry then break end
			log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": " .. info.error .. ", provo un altro tracciato"
		end
		if not ok and info.retry and not CC.SKIP_DETOUR then
			ok, info = railDetour(ea, eb, log, "binario " .. i .. "-" .. (i + 1))
		end
		-- l'alta velocita' non sempre e' consentita (passaggi a livello, curve): riprovo con binario standard
		if not ok and not CC.trackOverride and CC.railEra().track == "high_speed" and not tostring(info.error):find("acqua", 1, true) then
			CC.trackOverride = "standard"
			log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": alta velocita' rifiutata (" .. tostring(info.error) .. "), uso binario standard"
			ok, info = CC.buildCurvedTrack(ea, eb, 60, false)
		end
		if not ok then
			local msg = info.error
			if info.detail and info.detail.msg then msg = msg .. " (" .. table.concat(info.detail.msg, "; ") .. ")" end
			return { ok = false, error = "binario " .. i .. "-" .. (i + 1) .. ": " .. msg, detail = info.detail, bad_segments = info.badSegments, log = log }
		end
		for _, e in ipairs(info.edges or {}) do builtEdges_[#builtEdges_ + 1] = e end
		log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": " .. info.length .. " m, " .. (info.bridges or 0) .. " tratti su ponte, "
			.. (info.tunnels or 0) .. " in galleria, " .. (info.crossings or 0) .. " passaggi a livello, " .. (info.overpasses or 0) .. " sovrappassi, " .. (info.underpasses or 0) .. " sottopassi"
	end
	-- deposito dietro l'estremo libero della prima stazione (o dell'ultima)
	local depot
	for _, si in ipairs({ 1, #stations }) do
		for _, e in ipairs(stations[si].ends) do
			if not used[e.node] and not depot then
				local okD, D = CC.buildRailDepotAtEnd(e, "Deposito " .. (CC.nameOf(stations[si].town) or ""))
				if okD then depot = D.depot; used[e.node] = true; built_[#built_ + 1] = D.construction else log[#log + 1] = "deposito: " .. tostring(D.error) end
			end
		end
	end
	if not depot then return { ok = false, error = "deposito ferroviario non costruito", log = log } end
	local groups = {}
	for i, st in ipairs(stations) do groups[i] = st.group end
	-- verifica percorso treni (con la modalita' della locomotiva che verra' comprata: elettrica o no)
	local loco = CC.pickLocomotive(CC.railEra().catenary)
	if not loco then return { ok = false, error = "nessuna locomotiva disponibile quest'anno", log = log } end
	local mode = loco.electric and TM.ELECTRIC_TRAIN or TM.TRAIN
	local dOut = CC.depotNodes(depot)
	if not CC.hasPath(dOut, CC.stopNodeId(groups[1]), { mode }) and not CC.hasPath(dOut, CC.stopNodeId(groups[#groups]), { mode }) then
		return { ok = false, error = "il deposito non raggiunge le stazioni" .. (loco.electric and " (treno elettrico)" or ""), stations = groups, depot_id = depot, log = log }
	end
	for i = 1, #groups - 1 do
		if not CC.hasPath(CC.stopNodeId(groups[i]), CC.stopNodeId(groups[i + 1]), { mode }) then
			return { ok = false, error = "binari costruiti ma i treni non trovano il percorso " .. i .. "-" .. (i + 1), stations = groups, depot_id = depot, log = log }
		end
	end
	local okL, li = CC.createLine(a.name or "Treno", groups)
	if not okL then return { ok = false, error = li.error, stations = groups, depot_id = depot } end
	local trains, errs = {}, {}
	-- binario unico senza incroci: con piu' treni si bloccano a vicenda. Per ora un treno per linea.
	-- binario unico: i treni si incrociano solo nelle stazioni (2 binari). Al massimo un treno per stazione.
	local nTrains = math.max(1, math.min(6, a.num_trains or 1))
	local maxT = (stations[1].tracks == 2) and #stations or 1
	if nTrains > maxT then
		log[#log + 1] = "binario unico con incroci solo in stazione: compro " .. maxT .. " treni invece di " .. nTrains
		nTrains = maxT
	end
	for _ = 1, nTrains do
		local okT, T = CC.buyTrain(depot, li.line, a.num_cars or 3)
		if okT then trains[#trains + 1] = T.vehicle else errs[#errs + 1] = T.error end
	end
	return { ok = #trains > 0 and #errs == 0, line_id = li.line, stations = groups, depot_id = depot, trains = trains, errors = errs, log = log }
end

-- Se la linea non si completa, rimuove le costruzioni appena fatte (stazioni, deposito) per non lasciare
-- lavori a meta' nella partita. I binari gia' posati restano solo se la linea e' andata a buon fine.
SIM_ACTIONS.build_rail_line = function(a)
	local built, builtEdges = {}, {}
	CC.trackOverride = nil
	local ok, r = pcall(buildRailLine, a, built, builtEdges)
	if not ok then r = { ok = false, error = tostring(r) } end
	if not r.ok and not r.line_id then
		local removed = 0
		for i = #built, 1, -1 do if CC.removeConstruction(built[i]) then removed = removed + 1 end end
		local _, nE = CC.removeEdges(builtEdges)
		r.cleanup = removed .. " costruzioni e " .. tostring(nE or 0) .. " tratti di binario rimossi"
	end
	r.era = CC.railEra()
	r.era.track_used = CC.trackOverride or r.era.track
	CC.trackOverride = nil
	return r
end
-- ===================================================================== BOZZA (NON TESTATO) - b1 base
-- Va caricata DOPO cc_lib.lua e cc_actions.lua (stesso blocco: usa i loro "local", es. SIM_ACTIONS).
-- Contenuto: registro di cio' che ogni azione costruisce (per "annulla"), verifica a secco delle proposte,
-- controllo degli argomenti, funzioni comuni su linee, veicoli, depositi e bacini delle stazioni.
-- Le funzioni dell'API usate qui sono gia' verificate in gioco, salvo dove c'e' scritto DA VERIFICARE.

-- ---------------------------------------------------------------- registro delle entita' create
-- CC.send viene "avvolta": durante un'azione (registro aperto con CC.txBegin) ogni comando riuscito aggiunge al registro le
-- entita' create. Alla fine l'azione restituisce result.created = { vehicles, lines, constructions, tracks, roads },
-- che il middleware salva per poter annullare.
-- I registri si possono annidare (un'azione che ne chiama un'altra): ogni comando va in tutti quelli aperti.
CC._txStack = CC._txStack or {}
local CC_sendOrig = CC.send
function CC.send(cmd)
	local ok, res, ents = CC_sendOrig(cmd)
	if ok and #CC._txStack > 0 then
		local newE, newV = {}, {}
		for _, e in ipairs(ents or {}) do newE[#newE + 1] = e end
		pcall(function() local e = res.resultEntity; if e and e >= 0 then newE[#newE + 1] = e end end)
		pcall(function() local v = res.resultVehicleEntity; if v and v >= 0 then newV[#newV + 1] = v end end)
		for _, tx in ipairs(CC._txStack) do
			for _, e in ipairs(newE) do tx.ents[#tx.ents + 1] = e end
			for _, v in ipairs(newV) do tx.vehicles[#tx.vehicles + 1] = v end
		end
	end
	return ok, res, ents
end

function CC.txBegin() CC._txStack[#CC._txStack + 1] = { ents = {}, vehicles = {} } end
function CC.txEnd() local tx = CC._txStack[#CC._txStack]; CC._txStack[#CC._txStack] = nil; return tx end

-- Divide le entita' registrate per tipo (solo quelle che esistono ancora).
-- tracks: segmenti di binario (e di superstrada) fuori dalle costruzioni; roads: segmenti di strada nuovi (non si annullano: possono
-- essere pezzi di strade cittadine spezzate per un passaggio a livello o rifatte con i binari del tram).
function CC.txClassify(tx)
	local CT = api.type.ComponentType
	local out = { vehicles = {}, lines = {}, constructions = {}, tracks = {}, roads = {} }
	local seen = {}
	for _, v in ipairs(tx and tx.vehicles or {}) do
		if not seen[v] and api.engine.entityExists(v) then seen[v] = true; out.vehicles[#out.vehicles + 1] = v end
	end
	for _, e in ipairs(tx and tx.ents or {}) do
		if not seen[e] and api.engine.entityExists(e) then
			seen[e] = true
			if CC.comp(e, CT.LINE) then
				out.lines[#out.lines + 1] = e
			elseif CC.comp(e, CT.CONSTRUCTION) then
				out.constructions[#out.constructions + 1] = e
			elseif CC.comp(e, CT.TRANSPORT_VEHICLE) then
				out.vehicles[#out.vehicles + 1] = e
			else
				local be = CC.comp(e, CT.BASE_EDGE)
				if be and not CC.inConstruction(e) then
					local tp = tostring(be.roadTemplate)
					if tp:find("/track/", 1, true) or tp:find("highway", 1, true) or tp:find("motorway", 1, true) then out.tracks[#out.tracks + 1] = e
					else out.roads[#out.roads + 1] = e end
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- verifica a secco
-- Valuta la proposta senza costruire (makeProposalData, verificato nella diagnosi dei binari).
-- Se gia' la verifica lancia un'eccezione, la proposta NON va inviata: e' il caso che ha corrotto la partita.
function CC.dryRun(prop)
	local okP, pd = pcall(api.engine.util.proposal.makeProposalData, prop, nil)
	if not okP then return false, { exception = tostring(pd):sub(1, 160) } end
	local info = { critical = false, msg = {} }
	pcall(function()
		info.critical = pd.errorState.critical
		for _, m in ipairs(CC.each(pd.errorState.messages)) do info.msg[#info.msg + 1] = tostring(m) end
	end)
	return not info.critical, info
end

-- Al posto di pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignore, true): prima la verifica a secco.
-- Ritorna ok, comando (oppure false, testo dell'errore).
-- Da usare anche nel codice gia' esistente quando si unisce la bozza (sostituzione meccanica).
function CC.buildCmd(prop, ignoreErrors)
	local okD, info = CC.dryRun(prop)
	if info and info.exception then return false, "il gioco rifiuta la proposta gia' in verifica: " .. info.exception end
	if not okD and ignoreErrors ~= true then return false, "proposta non valida: " .. table.concat(info.msg or {}, "; ") end
	return pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignoreErrors == true, true)
end

-- ---------------------------------------------------------------- controllo argomenti nella mod
-- spec: { campo = "int" | "int?" | "ints" | "str?" | "num?" | "bool?" | "id" | "ids" }  (? = facoltativo).
-- "id"/"ids": numeri di entita' che devono esistere nella partita. Errore leggibile se non va.
-- I campi sono controllati in ordine alfabetico, cosi' l'errore e' sempre lo stesso a parita' di argomenti.
function CC.need(a, spec)
	if type(a) ~= "table" then error("argomenti mancanti", 0) end
	local keys = {}
	for k in pairs(spec) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local t = spec[k]
		local v = a[k]
		local opt = t:sub(-1) == "?"
		local base = opt and t:sub(1, -2) or t
		if v == nil then
			if not opt then error("argomento mancante: " .. k, 0) end
		elseif base == "int" or base == "num" or base == "id" then
			if type(v) ~= "number" then error("argomento " .. k .. ": atteso un numero", 0) end
			if base == "int" and v ~= math.floor(v) then error("argomento " .. k .. ": atteso un numero intero", 0) end
			if base == "id" and not api.engine.entityExists(v) then error("argomento " .. k .. ": l'entita' " .. v .. " non esiste", 0) end
		elseif base == "ints" or base == "ids" then
			if type(v) ~= "table" or #v == 0 then error("argomento " .. k .. ": attesa una lista di numeri", 0) end
			for _, x in ipairs(v) do
				if type(x) ~= "number" then error("argomento " .. k .. ": attesa una lista di numeri", 0) end
				if base == "ids" and not api.engine.entityExists(x) then error("argomento " .. k .. ": l'entita' " .. x .. " non esiste", 0) end
			end
		elseif base == "str" then
			if type(v) ~= "string" then error("argomento " .. k .. ": atteso un testo", 0) end
		elseif base == "bool" then
			if type(v) ~= "boolean" then error("argomento " .. k .. ": atteso vero/falso", 0) end
		end
	end
end

-- ---------------------------------------------------------------- stato della partita
function CC.gameSpeed()
	local s
	pcall(function() s = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup end)
	return s
end

-- ---------------------------------------------------------------- pulizie prudenti
-- VERIFICATO (crash del 07.10.2026 su mappa nuova): togliere nello stesso momento binari appena fatti e la stazione a
-- cui sono attaccati fa scattare nel gioco "AreAllNodesEmpty" e poi il crash. Con CC.SAFE_CLEANUP (default) dopo un
-- fallimento NON si tolgono binari ne' costruzioni con binari attaccati: restano come "avanzi" (CC._leftovers, campo
-- leftovers del risultato) e si tolgono dopo, a mano o con un'azione apposta. Si tolgono solo costruzioni isolate.
-- ---------------------------------------------------------------- confini della mappa
-- VERIFICATO (s20, s21): getBoundingBox() da' Box2 {min, max} (mappa di prova: -8192..8192); isValidCoordinate(Vec2f)
-- e' false fuori; oltre il bordo getHeightAt ripete l'ultimo valore.
-- Il terreno offre getBoundingBox e isValidCoordinate; se non rispondono si usa CC.MAP_HALF.
CC.MAP_MARGIN = CC.MAP_MARGIN or 300
CC.MAP_HALF = CC.MAP_HALF or 8000
local function terr() return api.engine.terrain or (api.engine.util and api.engine.util.terrain) end
local function num(v) return type(v) == "number" and v or nil end
function CC.mapBox()
	if CC._mapBox then return CC._mapBox end
	local box
	pcall(function()
		local b = terr().getBoundingBox()
		local mn, mx = b.min or b[1], b.max or b[2]
		if mn and mx and num(mn.x) and num(mx.x) and mx.x > mn.x then
			box = { minX = mn.x, minY = mn.y, maxX = mx.x, maxY = mx.y, src = "getBoundingBox" }
		end
	end)
	if not box then
		-- bordo: dove l'altezza smette di cambiare andando verso l'esterno
		local function edge(ax, ay)
			local last, lastR = nil, nil
			for R = 20000, 2000, -250 do
				local ok, h = pcall(function() return terr().getHeightAt(api.type.Vec2f.new(ax * R, ay * R)) end)
				if ok and type(h) ~= "number" then ok = false end
				if not ok then return nil end
				if last and math.abs(h - last) > 0.05 then return lastR end
				last, lastR = h, R
			end
			return nil
		end
		local px, nx, py, ny = edge(1, 0), edge(-1, 0), edge(0, 1), edge(0, -1)
		local H = CC.MAP_HALF
		box = { minX = -(nx or H), maxX = px or H, minY = -(ny or H), maxY = py or H, src = "altezze" }
	end
	CC._mapBox = box
	return box
end
-- (x, y) dentro la mappa con almeno `m` metri dal bordo?
function CC.inMap(x, y, m)
	if not x or not y then return false end
	m = m or CC.MAP_MARGIN
	local b = CC.mapBox()
	if x < b.minX + m or x > b.maxX - m or y < b.minY + m or y > b.maxY - m then return false end
	local valid = true
	pcall(function()
		local r = terr().isValidCoordinate(api.type.Vec2f.new(x, y))
		if r == false then valid = false end
	end)
	return valid
end

CC.SAFE_CLEANUP = (CC.SAFE_CLEANUP == nil) and true or CC.SAFE_CLEANUP
CC._leftovers = CC._leftovers or { constructions = {}, edges = {} }

function CC.noteLeftovers(cons, edges)
	for _, c in ipairs(cons or {}) do CC._leftovers.constructions[#CC._leftovers.constructions + 1] = c end
	for _, e in ipairs(edges or {}) do CC._leftovers.edges[#CC._leftovers.edges + 1] = e end
end

-- Toglie una costruzione con eventuali binari attaccati. In modo prudente: se ci sono binari, lascia tutto.
function CC.safeRemove(con, edges)
	if CC.SAFE_CLEANUP and edges and #edges > 0 then
		CC.noteLeftovers({ con }, edges)
		return false
	end
	if edges and #edges > 0 then CC.removeEdges(edges) end
	return CC.removeConstruction(con)
end

-- Annulla quanto costruito da un'azione fallita. Ritorna il testo per r.cleanup e gli avanzi.
function CC.rollback(built, builtEdges)
	if CC.SAFE_CLEANUP and builtEdges and #builtEdges > 0 then
		CC.noteLeftovers(built, builtEdges)
		return "nessuna rimozione (pulizia prudente): " .. #built .. " costruzioni e " .. #builtEdges .. " tratti lasciati",
			{ constructions = built, edges = builtEdges }
	end
	local removed = 0
	for i = #built, 1, -1 do if CC.removeConstruction(built[i]) then removed = removed + 1 end end
	return removed .. " costruzioni rimosse (nessun binario da togliere)", nil
end

-- ---------------------------------------------------------------- linee e veicoli
function CC.lineVehicles(L)
	local out = {}
	pcall(function() out = CC.each(api.engine.system.transportVehicleSystem.getLineVehicles(L)) end)
	return out
end

function CC.lineGroups(L)
	local lc = CC.comp(L, api.type.ComponentType.LINE)
	if not lc then return nil end
	local g = {}
	for _, s in ipairs(CC.each(lc.stops)) do g[#g + 1] = s.stationGroup end
	return g
end

-- Modi di trasporto della linea. VERIFICATO (salvataggio di terzi, sonda s14): getLineTransportModesUnion da' i modi
-- giusti (es. bus 3 + 4, treno 7, 8, 14, 15); lc.vehicleInfo.transportModes ha indice = modo (NON modo+1).
function CC.lineModes(L)
	local modes = {}
	pcall(function()
		for k, on in pairs(api.engine.util.line.getLineTransportModesUnion(L)) do
			local m = tonumber(k)
			if on and m then modes[#modes + 1] = m end
		end
	end)
	if #modes == 0 then
		pcall(function()
			local tm = CC.comp(L, api.type.ComponentType.LINE).vehicleInfo.transportModes
			for i = 0, 32 do
				local on = false
				pcall(function() on = tm[i] end)
				if on then modes[#modes + 1] = i end
			end
		end)
	end
	table.sort(modes)
	return modes
end

-- Fermate della linea (strutture Line.Stop: stationGroup, station, terminal; station e terminal da 0).
function CC.lineStops(L)
	local lc = CC.comp(L, api.type.ComponentType.LINE)
	return lc and CC.each(lc.stops) or {}
end

-- Nodo e stazione di una fermata della linea: quella indicata da stop.station/stop.terminal. VERIFICATO (s13/s14):
-- nei gruppi con piu' stazioni (fermata bus accanto alla ferrovia) la prima stazione del gruppo non e' quella giusta.
function CC.lineStopNode(stop)
	local CT = api.type.ComponentType
	local sg = CC.comp(stop.stationGroup, CT.STATION_GROUP)
	local st = sg and CC.each(sg.stations)[(stop.station or 0) + 1]
	local sc = st and CC.comp(st, CT.STATION)
	local t = sc and CC.each(sc.terminals)[(stop.terminal or 0) + 1]
	return t and t.vehicleNodeId, st
end

-- Nodi (primo terminale di ogni stazione) di un gruppo di stazioni.
function CC.groupNodes(g)
	local CT = api.type.ComponentType
	local out = {}
	local sg = CC.comp(g, CT.STATION_GROUP)
	for _, st in ipairs(sg and CC.each(sg.stations) or {}) do
		local sc = CC.comp(st, CT.STATION)
		local t = sc and CC.each(sc.terminals)[1]
		if t then out[#out + 1] = t.vehicleNodeId end
	end
	return out
end

-- Percorso tra due gruppi: prova tutte le coppie di stazioni (un gruppo puo' avere fermata bus + ferrovia).
function CC.groupPath(g1, g2, modes)
	for _, a in ipairs(CC.groupNodes(g1)) do
		for _, b in ipairs(CC.groupNodes(g2)) do
			if CC.hasPath(a, b, modes) then return true end
		end
	end
	return false
end

-- Edifici/industrie nel bacino di tutte le stazioni del gruppo.
function CC.groupCatchables(g)
	local n = 0
	local sg = CC.comp(g, api.type.ComponentType.STATION_GROUP)
	for _, st in ipairs(sg and CC.each(sg.stations) or {}) do n = n + #CC.stationCatchables(st) end
	return n
end

-- Quante linee del giocatore fermano in ogni gruppo (nodi di scambio: fermate senza bacino ma con piu' linee).
function CC.groupLineCounts()
	local cnt = {}
	pcall(function()
		for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
			local seen = {}
			for _, s in ipairs(CC.lineStops(L)) do
				if not seen[s.stationGroup] then seen[s.stationGroup] = true; cnt[s.stationGroup] = (cnt[s.stationGroup] or 0) + 1 end
			end
		end
	end)
	return cnt
end

-- Modelli (id) dei pezzi di un veicolo, nell'ordine (locomotiva per prima).
function CC.vehicleModels(v)
	local ids = {}
	pcall(function()
		local tv = CC.comp(v, api.type.ComponentType.TRANSPORT_VEHICLE)
		for _, p in ipairs(CC.each(tv.transportVehicleConfig.vehicles)) do ids[#ids + 1] = p.part.modelId end
	end)
	return ids
end

-- Tipi di merce (id) che un modello puo' caricare, passeggeri esclusi.
function CC.modelCargoTypes(modelId)
	local P = CC.passengerCargo()
	local set, out = {}, {}
	pcall(function()
		local tv = api.res.modelRep.get(modelId).metadata.transportVehicle
		for _, cpt in ipairs(CC.each(tv.compartments)) do
			for _, lc in ipairs(CC.each(cpt.loadConfigs)) do
				pcall(function()
					api.res.cargoTypeRep.forEachCargoType(lc.cargoEntry.cargoTypeSet, function(cid)
						if cid ~= P and not set[cid] then set[cid] = true; out[#out + 1] = cid end
					end)
				end)
			end
		end
	end)
	return out
end

-- Cartella del modello: "bus", "tram", "truck", "train", "waggon", "plane", "ship", ...
function CC.modelFolder(modelId)
	local name = ""
	pcall(function() name = api.res.modelRep.getName(modelId) end)
	return name:match("/vehicle/([^/]+)/") or "?", name
end

-- Deposito del giocatore che raggiunge la prima fermata della linea (il piu' vicino).
function CC.depotForLine(L)
	local groups = CC.lineGroups(L)
	if not groups or #groups == 0 then return nil end
	local modes = CC.lineModes(L)
	if #modes == 0 then
		-- ripiego: modi del motore del primo veicolo della linea
		local v = CC.lineVehicles(L)[1]
		local m = v and CC.vehicleModels(v)[1]
		pcall(function()
			for _, tm in ipairs(CC.each(api.res.modelRep.get(m).metadata.transportVehicle.engineTransportModes)) do modes[#modes + 1] = tm end
		end)
	end
	local p = CC.posOf(groups[1])
	local target = CC.lineStops(L)[1] and CC.lineStopNode(CC.lineStops(L)[1]) or CC.stopNodeId(groups[1])
	local best, bd
	for _, d in ipairs(CC.playerDepots()) do
		local dist = (p and d.x) and math.sqrt((d.x - p.x) ^ 2 + (d.y - p.y) ^ 2) or 1e9
		if not bd or dist < bd then
			local dOut = CC.depotNodes(d.depot)
			if #modes > 0 and CC.hasPath(dOut, target, modes) then best, bd = d.depot, dist end
		end
	end
	return best
end

-- Compra un veicolo composto dai modelli dati (es. locomotiva + carrozze) e lo assegna alla linea.
function CC.buyComposition(depot, models, line, stopIndex)
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local gt = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local parts, groups = {}, {}
	for i, id in ipairs(models) do
		local p = vu.makePart(id, true, nil)
		p.purchaseTime = gt and math.floor(gt.gameTime) or 0
		local auto = {}
		for k = 1, math.max(1, #CC.each(p.part.compartment2loadConfig)) do auto[k] = true end
		p.autoLoadConfig = auto
		parts[i] = p
		groups[i] = 1
	end
	local cfg = api.type.TransportVehicleConfig.new()
	cfg.vehicles = parts
	cfg.vehicleGroups = groups
	cfg.muFileNames = {}
	local ok, res = CC.send(api.cmd.makeVehicleBuyCmd(api.engine.util.getPlayer(), depot, cfg))
	local veh
	pcall(function() veh = res.resultVehicleEntity end)
	if not ok or not veh or veh < 0 then return false, "acquisto fallito" end
	if line then
		local ok2 = CC.send(api.cmd.makeVehicleSetLineCmd(veh, line, stopIndex or 0))
		if not ok2 then return true, veh, "assegnazione alla linea fallita" end
	end
	return true, veh
end

function CC.sellVehicles(list)
	local sold, errs = 0, {}
	local player = api.engine.util.getPlayer()
	for _, v in ipairs(list) do
		if api.engine.entityExists(v) then
			local ok = CC.send(api.cmd.makeVehicleSellCmd({ v }, player))
			if ok then sold = sold + 1 else errs[#errs + 1] = "vendita " .. v .. " fallita" end
		end
	end
	return sold, errs
end

-- ---------------------------------------------------------------- bacino delle stazioni
-- Cosa "vede" una stazione (edifici, industrie, magazzini nel bacino). Fonte: script ufficiale delle notifiche
-- ("stazione non funzionante"): api.engine.system.catchmentAreaSystem.getStationCatchables(station, true).
function CC.stationCatchables(station)
	local list = {}
	pcall(function() list = CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(station, true)) end)
	return list
end

function CC.groupStation(group)
	local sg = CC.comp(group, api.type.ComponentType.STATION_GROUP)
	return sg and CC.each(sg.stations)[1]
end

-- La stazione vede l'industria? (confronto sia con l'entita' industria sia con la sua costruzione) DA VERIFICARE
-- il formato degli elementi restituiti: provo sia numeri sia strutture con .entity.
function CC.stationCatches(station, ind)
	local ic = CC.comp(ind, api.type.ComponentType.INDUSTRY)
	local con = ic and ic.construction
	for _, c in ipairs(CC.stationCatchables(station)) do
		local e = c
		if type(c) ~= "number" then pcall(function() e = c.entity end) end
		if e == ind or (con and e == con) then return true end
	end
	return false
end

-- Edifici di citta' entro r metri (stima veloce del bacino passeggeri di un punto).
function CC.townBuildingsNear(x, y, r)
	local n = 0
	pcall(function()
		n = #CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, api.type.ComponentType.TOWN_BUILDING))
	end)
	return n
end

-- Fermata stradale del giocatore entro r metri da (x, y), se c'e' (per riusarla).
function CC.playerStopNear(x, y, r, needRoad)
	local best, bd
	for g in pairs(CC.playerGroups()) do
		local p = CC.posOf(g)
		if p then
			local d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
			if d < r and (not bd or d < bd) then
				local okRoad = true
				if needRoad then
					okRoad = false
					pcall(function()
						local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
						for _, c in ipairs(CC.each(car[1])) do if c == api.type.enum.Carrier.ROAD then okRoad = true end end
					end)
				end
				if okRoad then best, bd = g, d end
			end
		end
	end
	return best, bd
end
-- ===================================================================== fine b1
-- ===================================================================== BOZZA (NON TESTATO) - b2 rete
-- Azioni nuove: bus tra citta', navetta stazione-centro, aggiungi/togli/sostituisci veicoli, allunga/cancella
-- linea, annulla. Usa b1 e le funzioni gia' verificate di cc_lib/cc_actions.

-- Fermata stradale nel centro di una citta': riusa quella del giocatore piu' vicina (entro reuseR) o ne costruisce una.
function CC.townStop(town, name, reuseR)
	local c = CC.posOf(town)
	if not c then return nil, "citta' " .. tostring(town) .. " non trovata" end
	local g = CC.playerStopNear(c.x, c.y, reuseR or 250, true)
	if g then return g, nil, false end
	local ok, info = CC.buildStopNear(c.x, c.y, name, { radius = 350, avoid = playerStopsNear(c.x, c.y, 300), spacing = 100 })
	if not ok then return nil, "fermata a " .. (CC.nameOf(town) or "?") .. ": " .. tostring(info.error) end
	return info.group, nil, true
end

-- ---------------------------------------------------------------- flotta iniziale (punto 4b/2b.1)
-- Alla CREAZIONE di una linea, se Nicolo' non ha indicato il numero di veicoli, la mod stima il giro dalla distanza
-- tra le fermate (in linea d'aria x fattore percorso), dalla velocita' massima del modello (ridotta per accelerazioni,
-- curve e centri abitati) e dalla sosta alle fermate; poi mette i veicoli per un passaggio ogni CC.FLEET_INTERVAL.
-- Stima soltanto: dopo un giro vero `check_line_fleet` misura i tempi reali. NON VERIFICATO IN GIOCO: il campo
-- metadata.<tipo>Vehicle.topSpeed (m/s in TF2) va confermato in TF3; se manca si usa CC.FLEET_SPEED.
CC.FLEET_INTERVAL = CC.FLEET_INTERVAL or { bus = 240, tram = 240, truck = 300, train = 480, waggon = 480, ship = 900, plane = 900, helicopter = 600 }
CC.FLEET_SPEED = CC.FLEET_SPEED or { bus = 22, tram = 17, truck = 22, train = 33, waggon = 33, ship = 12, plane = 100, helicopter = 60 }   -- m/s
CC.FLEET_DETOUR = CC.FLEET_DETOUR or { bus = 1.35, tram = 1.35, truck = 1.35, train = 1.2, waggon = 1.2, ship = 1.3, plane = 1.05, helicopter = 1.05 }
CC.FLEET_DWELL = CC.FLEET_DWELL or { bus = 25, tram = 25, truck = 40, train = 45, waggon = 60, ship = 90, plane = 120, helicopter = 60 }   -- s per fermata
CC.FLEET_SPEED_FACTOR = CC.FLEET_SPEED_FACTOR or 0.65   -- velocita' media / velocita' massima
CC.FLEET_MAX = CC.FLEET_MAX or { bus = 10, tram = 10, truck = 10, train = 4, waggon = 4, ship = 6, plane = 6, helicopter = 6 }

-- Velocita' massima del modello in m/s (metadata), oppure nil.
function CC.modelTopSpeed(modelId)
	local v
	pcall(function()
		local md = api.res.modelRep.get(modelId).metadata
		for _, k in ipairs({ "roadVehicle", "railVehicle", "waterVehicle", "airVehicle" }) do
			local t = md[k] and md[k].topSpeed
			if type(t) == "number" and t > 0 then v = t; return end
		end
	end)
	return v
end

-- Calcolo puro (testabile senza gioco): pos = posizioni {x,y} delle fermate nell'ordine della linea (la linea torna
-- dall'ultima alla prima), speed = velocita' massima in m/s o nil. Ritorna numero di veicoli e dettagli.
function CC.estimateFleet(pos, speed, folder, opts)
	opts = opts or {}
	local dist = 0
	local n = #pos
	for i = 1, n do
		local a, b = pos[i], pos[i % n + 1]
		if a and b and a ~= b then dist = dist + math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
	end
	local top = speed or CC.FLEET_SPEED[folder] or 20
	local vAvg = top * CC.FLEET_SPEED_FACTOR
	local rtt = dist * (CC.FLEET_DETOUR[folder] or 1.3) / vAvg + n * (CC.FLEET_DWELL[folder] or 30)
	local interval = opts.interval or CC.FLEET_INTERVAL[folder] or 300
	local maxN = opts.max or CC.FLEET_MAX[folder] or 10
	local count = math.max(1, math.min(maxN, math.ceil(rtt / interval)))
	return count, { estimated = true, round_trip_s = math.floor(rtt), route_m = math.floor(dist), interval_target = interval,
		top_speed_ms = math.floor(top * 10) / 10, speed_from_model = speed ~= nil, count = count, max = maxN }
end

-- Numero iniziale di veicoli per una linea con le fermate `stops` (gruppi, nell'ordine della linea).
-- requested = numero chiesto da Nicolo' (vince sempre, nei limiti `hardMax`).
function CC.initialFleet(stops, modelId, folder, requested, hardMax)
	if requested then return math.max(1, math.min(hardMax or 20, requested)), { estimated = false, count = requested } end
	local pos = {}
	for i, g in ipairs(stops) do pos[i] = CC.posOf(g) end
	if #pos < #stops then return 2, { estimated = false, count = 2, error = "posizioni delle fermate non trovate: 2 veicoli" } end
	return CC.estimateFleet(pos, modelId and CC.modelTopSpeed(modelId), folder, { max = hardMax and math.min(hardMax, CC.FLEET_MAX[folder] or hardMax) })
end

-- ---------------------------------------------------------------- bus tra citta'
SIM_ACTIONS.build_intercity_bus = function(a)
	CC.need(a, { town_ids = "ints", num_vehicles = "int?", name = "str?" })
	local TM = api.type.enum.TransportMode
	local towns = a.town_ids
	if #towns < 2 then return { ok = false, error = "servono almeno 2 citta'" } end
	local groups, log = {}, {}
	for i, t in ipairs(towns) do
		local g, err, built = CC.townStop(t, (CC.nameOf(t) or "Citta'") .. " autolinee", 250)
		if not g then return { ok = false, error = err, stations = groups, log = log } end
		log[#log + 1] = (CC.nameOf(t) or "?") .. ": " .. (built and "fermata nuova" or "fermata esistente riusata")
		groups[i] = g
	end
	-- strada percorribile in tutti e due i versi tra fermate consecutive (e dall'ultima alla prima)
	for i = 1, #groups do
		local g1, g2 = groups[i], groups[i % #groups + 1]
		if not CC.groupPath(g1, g2, { TM.BUS }) then
			return { ok = false, error = "nessuna strada per bus tra " .. (CC.nameOf(towns[i]) or "?") .. " e " .. (CC.nameOf(towns[i % #towns + 1]) or "?"), stations = groups, log = log }
		end
	end
	local p = CC.posOf(groups[1])
	local depot, builtD = ensureRoadDepot(groups[1], p.x, p.y, "Deposito " .. (CC.nameOf(towns[1]) or ""))
	local names = {}
	for _, t in ipairs(towns) do names[#names + 1] = CC.nameOf(t) or "?" end
	local okL, li = CC.createLine(a.name or ("Bus " .. table.concat(names, " - ")), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, depot_id = depot, log = log } end
	local model = CC.pickModel("bus", nil, { passengers = true })
	if not model then return { ok = false, error = "nessun bus disponibile quest'anno", line_id = li.line } end
	local n, fleet = CC.initialFleet(groups, model.id, "bus", a.num_vehicles, 10)
	local okV, v = CC.buyVehicles(depot, model.id, n, li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, depot_built = builtD,
		vehicles = v.vehicles, model = model.name, errors = v.errors, log = log, fleet = fleet }
end

-- ---------------------------------------------------------------- navetta stazione - centro (nodo di scambio)
-- Fermata bus accanto alla stazione (o una gia' esistente) + fermata in centro + linea con bus.
SIM_ACTIONS.connect_station_to_town = function(a)
	CC.need(a, { station_id = "int", town_id = "int?", num_vehicles = "int?" })
	local TM = api.type.enum.TransportMode
	local sp = CC.posOf(a.station_id)
	if not sp then return { ok = false, error = "stazione " .. tostring(a.station_id) .. " non trovata" } end
	local town = a.town_id
	if not town then
		pcall(function() town = api.engine.system.stationSystem.getTown(CC.groupStation(a.station_id)) end)
	end
	if not town or town < 0 then return { ok = false, error = "non so a quale citta' collegare la stazione: indica town_id" } end
	local log = {}
	-- fermata vicino alla stazione: esistente entro 150 m, altrimenti nuova
	local gS = CC.playerStopNear(sp.x, sp.y, 150, true)
	if gS == a.station_id then gS = nil end
	if not gS then
		local ok, info = CC.buildStopNear(sp.x, sp.y, (CC.nameOf(a.station_id) or "Stazione") .. " bus", { radius = 250, avoid = {}, spacing = 60 })
		if not ok then return { ok = false, error = "nessuna strada vicino alla stazione per la fermata bus: " .. tostring(info.error) } end
		gS = info.group
		log[#log + 1] = "fermata bus nuova vicino alla stazione"
	else
		log[#log + 1] = "fermata bus esistente vicino alla stazione"
	end
	local gC, err = CC.townStop(town, (CC.nameOf(town) or "Centro") .. " centro", 250)
	if not gC then return { ok = false, error = err, log = log } end
	if gC == gS then return { ok = false, error = "la stazione e' gia' in centro: navetta non necessaria", log = log } end
	if not CC.groupPath(gS, gC, { TM.BUS }) or not CC.groupPath(gC, gS, { TM.BUS }) then
		return { ok = false, error = "la fermata della stazione non e' collegata al centro su strada (andata e ritorno)", log = log }
	end
	local depot, builtD = ensureRoadDepot(gS, sp.x, sp.y, "Deposito " .. (CC.nameOf(town) or ""))
	local okL, li = CC.createLine("Navetta " .. (CC.nameOf(town) or "") .. " stazione", { gS, gC })
	if not okL then return { ok = false, error = li.error, log = log } end
	local model = CC.pickModel("bus", nil, { passengers = true })
	local n, fleet = CC.initialFleet({ gS, gC }, model.id, "bus", a.num_vehicles, 6)
	local okV, v = CC.buyVehicles(depot, model.id, n, li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = { gS, gC }, depot_id = depot, depot_built = builtD,
		vehicles = v.vehicles, errors = v.errors, log = log, fleet = fleet }
end

-- ---------------------------------------------------------------- veicoli di una linea
-- Aggiunge veicoli uguali a quelli gia' presenti sulla linea (stessa composizione).
SIM_ACTIONS.add_vehicles = function(a)
	CC.need(a, { line_id = "int", count = "int" })
	local vs = CC.lineVehicles(a.line_id)
	if #vs == 0 then return { ok = false, error = "la linea non ha veicoli da copiare: usa buy_and_assign_vehicles" } end
	local models = CC.vehicleModels(vs[1])
	if #models == 0 then return { ok = false, error = "composizione del veicolo non leggibile" } end
	local depot = CC.depotForLine(a.line_id)
	if not depot then return { ok = false, error = "nessun deposito raggiunge la linea" } end
	local nStops = math.max(1, #(CC.lineGroups(a.line_id) or {}))
	local bought, errs = {}, {}
	for i = 1, math.max(1, math.min(20, a.count)) do
		local ok, veh, warn = CC.buyComposition(depot, models, a.line_id, (#vs + i - 1) % nStops)
		if ok then bought[#bought + 1] = veh; if warn then errs[#errs + 1] = warn end else errs[#errs + 1] = veh; break end
	end
	return { ok = #bought > 0 and #errs == 0, vehicles = bought, errors = errs, depot_id = depot }
end

-- Vende gli ultimi `count` veicoli della linea (almeno uno resta, salva all=true).
SIM_ACTIONS.remove_vehicles = function(a)
	CC.need(a, { line_id = "int", count = "int" })
	local vs = CC.lineVehicles(a.line_id)
	local keep = a.all and 0 or 1
	local n = math.min(a.count, #vs - keep)
	if n <= 0 then return { ok = false, error = "sulla linea ci sono " .. #vs .. " veicoli: non ne tolgo (ne resta almeno uno)" } end
	local list = {}
	for i = #vs - n + 1, #vs do list[#list + 1] = vs[i] end
	local sold, errs = CC.sellVehicles(list)
	return { ok = sold == n, sold = sold, left = #vs - sold, errors = errs }
end

-- Flotta ON-DEMAND (punto 4b, solo su richiesta di Nicolo'): numero di veicoli per avere un passaggio ogni
-- `interval` secondi. Giro misurato dai tempi delle tratte dei veicoli (TRANSPORT_VEHICLE.sectionTimes, VERIFICATO s36
-- 09.10.2026: secondi per tratta, 0 = non ancora misurata). apply = true: compra/vende la differenza; altrimenti propone.
-- Treni: niente aggiunte automatiche (binario unico: si bloccherebbero) salvo force = true.
SIM_ACTIONS.adjust_line_fleet = function(a)
	CC.need(a, { line_id = "int", interval = "num?", apply = "bool?", max = "int?", force = "bool?" })
	local CT = api.type.ComponentType
	local vs = CC.lineVehicles(a.line_id)
	if #vs == 0 then return { ok = false, error = "la linea non ha veicoli" } end
	local nStops = #(CC.lineGroups(a.line_id) or {})
	-- media per tratta dei tempi misurati
	local sum, cnt = {}, {}
	for _, v in ipairs(vs) do
		local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
		local st = tv and tv.sectionTimes
		pcall(function()
			for i, t in ipairs(st) do
				if t and t > 0 then sum[i] = (sum[i] or 0) + t; cnt[i] = (cnt[i] or 0) + 1 end
			end
		end)
	end
	local rtt, missing = 0, 0
	for i = 1, math.max(nStops, 1) do
		if cnt[i] and cnt[i] > 0 then rtt = rtt + sum[i] / cnt[i] else missing = missing + 1 end
	end
	local models = CC.vehicleModels(vs[1])
	local folder = models[1] and CC.modelFolder(models[1]) or "?"
	local interval = a.interval or CC.FLEET_INTERVAL[folder] or 300
	local out = { vehicles = #vs, folder = folder, interval_target = interval, stops = nStops }
	if missing > 0 then
		out.ok = false
		out.error = "tempi del giro non ancora misurati (" .. missing .. " tratte su " .. nStops .. "): far correre il gioco finche' i veicoli hanno fatto un giro intero"
		return out
	end
	local target = math.max(1, math.min(a.max or 20, math.ceil(rtt / interval)))
	out.round_trip_s = math.floor(rtt)
	out.interval_now_s = math.floor(rtt / #vs)
	out.target = target
	out.change = target - #vs
	if (folder == "train" or folder == "waggon") and out.change > 0 and not a.force then
		out.note = "treni: non ne aggiungo da solo (su binario unico si bloccano); con binari d'incrocio o doppio binario usare force = true"
		out.change_applied = 0
		out.ok = true
		return out
	end
	if a.apply and out.change ~= 0 then
		if out.change > 0 then
			local r = SIM_ACTIONS.add_vehicles({ line_id = a.line_id, count = out.change })
			out.applied = r
		else
			local r = SIM_ACTIONS.remove_vehicles({ line_id = a.line_id, count = -out.change })
			out.applied = r
		end
		out.ok = out.applied and out.applied.ok
	else
		out.ok = true
		out.proposal = (out.change == 0) and "numero di veicoli adeguato"
			or ((out.change > 0 and ("aggiungere " .. out.change) or ("togliere " .. -out.change)) .. " veicoli (passaggio ogni " .. math.floor(rtt / target) .. " s invece di " .. out.interval_now_s .. " s)")
	end
	return out
end

-- Modello nuovo per un pezzo di veicolo: stesso tipo (cartella), il piu' recente adatto.
local function newerModel(oldId, catenary)
	local folder = CC.modelFolder(oldId)
	local pass, other = CC.modelLoads(oldId)
	if folder == "train" then
		local hasLoad = pass > 0 or other > 0
		if hasLoad then return nil end                      -- motrici con posti (automotrici): lasciate come sono
		local loco = CC.pickLocomotive(catenary)
		return loco and loco.id
	end
	if pass > 0 then
		local excl = folder == "waggon" and { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" } or { "cargo", "wagon" }
		local m = CC.pickModel(folder, excl, { passengers = true })
		return m and m.id
	end
	local cargos = CC.modelCargoTypes(oldId)
	if #cargos > 0 then
		local m = CC.pickModelForCargo(folder, cargos[1])
		return m and m.id
	end
	return nil
end

-- Sostituisce i veicoli della linea con modelli piu' recenti (comando ufficiale makeVehicleReplaceCmd,
-- come nello script delle missioni "replace_vehicles"). DA VERIFICARE in gioco.
SIM_ACTIONS.replace_vehicles = function(a)
	CC.need(a, { line_id = "int" })
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local gt = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local modes = CC.lineModes(a.line_id)
	local electric = false
	for _, m in ipairs(modes) do if m == api.type.enum.TransportMode.ELECTRIC_TRAIN then electric = true end end
	-- i treni restano elettrici solo se la linea lo e' gia' (una linea vecchia puo' non avere la catenaria)
	local catenary = electric
	local done, same, errs = 0, 0, {}
	for _, v in ipairs(CC.lineVehicles(a.line_id)) do
		local old = CC.vehicleModels(v)
		local parts, changed = {}, false
		for i, id in ipairs(old) do
			local nid = newerModel(id, catenary) or id
			if nid ~= id then changed = true end
			local p = vu.makePart(nid, true, nil)
			p.purchaseTime = gt and math.floor(gt.gameTime) or 0
			local auto = {}
			for k = 1, math.max(1, #CC.each(p.part.compartment2loadConfig)) do auto[k] = true end
			p.autoLoadConfig = auto
			parts[i] = p
		end
		if not changed then
			same = same + 1
		else
			local cfg = api.type.TransportVehicleConfig.new()
			cfg.vehicles = parts
			local groups = {}
			for i = 1, #parts do groups[i] = 1 end
			cfg.vehicleGroups = groups
			cfg.muFileNames = {}
			local ok = CC.send(api.cmd.makeVehicleReplaceCmd(v, cfg))
			if ok then done = done + 1 else errs[#errs + 1] = "sostituzione di " .. v .. " rifiutata" end
		end
	end
	return { ok = #errs == 0, replaced = done, already_newest = same, errors = errs }
end

-- ---------------------------------------------------------------- linee
-- Cancella una linea: prima vende i veicoli (il gioco non cancella linee con veicoli), poi makeLineDestroyCmd
-- (comando usato dagli script ufficiali delle missioni). Le stazioni restano.
SIM_ACTIONS.delete_line = function(a)
	CC.need(a, { line_id = "int" })
	if not CC.comp(a.line_id, api.type.ComponentType.LINE) then return { ok = false, error = "linea inesistente" } end
	local sold, errs = CC.sellVehicles(CC.lineVehicles(a.line_id))
	local ok = CC.send(api.cmd.makeLineDestroyCmd(a.line_id))
	if not ok then errs[#errs + 1] = "cancellazione della linea rifiutata" end
	return { ok = ok, sold = sold, errors = errs }
end

-- Allunga una linea su strada fino a una citta' (fermata nuova o esistente in fondo alla linea).
-- Usa makeLineUpdateCmd(linea, componente LINE modificato): comando esistente, effetto DA VERIFICARE.
SIM_ACTIONS.extend_line = function(a)
	CC.need(a, { line_id = "int", town_id = "int" })
	local TM = api.type.enum.TransportMode
	local lc = CC.comp(a.line_id, api.type.ComponentType.LINE)
	if not lc then return { ok = false, error = "linea inesistente" } end
	local groups = CC.lineGroups(a.line_id)
	local g, err = CC.townStop(a.town_id, (CC.nameOf(a.town_id) or "Citta'") .. " fermata", 250)
	if not g then return { ok = false, error = err } end
	local modes = CC.lineModes(a.line_id)
	if #modes == 0 then modes = { TM.BUS } end
	local last, first = groups[#groups], groups[1]
	if not CC.groupPath(last, g, modes) or not CC.groupPath(g, first, modes) then
		return { ok = false, error = "la nuova fermata non e' raggiungibile dai veicoli della linea" }
	end
	local stops = {}
	for _, s in ipairs(CC.each(lc.stops)) do stops[#stops + 1] = s end
	local st = api.type.Line.Stop.new()
	st.stationGroup = g; st.station = 0; st.terminal = 0
	stops[#stops + 1] = st
	-- build 40420: lc.stops e' in sola lettura (VERIFICATO p8 09.10.2026: "cannot write to read only member 'stops'"):
	-- linea nuova con tutte le fermate, poi makeLineUpdateCmd
	local line = api.type.Line.new()
	line.stops = stops
	pcall(function() line.waitingTime = lc.waitingTime end)
	pcall(function() line.vehicleInfo = lc.vehicleInfo end)
	local okC, cmd = pcall(api.cmd.makeLineUpdateCmd, a.line_id, line)
	if not okC then return { ok = false, error = "comando di modifica della linea: " .. tostring(cmd):sub(1, 120) } end
	local ok = CC.send(cmd)
	local after = CC.lineGroups(a.line_id) or {}
	return { ok = ok and #after == #groups + 1, stops_before = #groups, stops_after = #after, new_stop = g }
end

-- ---------------------------------------------------------------- annulla
-- a.created = quanto restituito da un'azione (result.created). Ordine: veicoli, linee, costruzioni, binari.
-- Le strade nuove non si toccano (possono essere strade cittadine rifatte): vengono solo elencate.
SIM_ACTIONS.undo = function(a)
	local c = a.created or {}
	local log = {}
	local sold, e1 = CC.sellVehicles(c.vehicles or {})
	log[#log + 1] = sold .. " veicoli venduti"
	-- i veicoli delle linee create (anche quelli comprati dopo) vanno venduti prima di cancellare la linea
	local nL = 0
	for _, L in ipairs(c.lines or {}) do
		if CC.comp(L, api.type.ComponentType.LINE) then
			local vs = CC.lineVehicles(L)
			if #vs > 0 then sold = sold + (CC.sellVehicles(vs) or 0) end
			if CC.send(api.cmd.makeLineDestroyCmd(L)) then nL = nL + 1 else log[#log + 1] = "linea " .. L .. " non cancellata" end
		end
	end
	log[#log + 1] = nL .. " linee cancellate"
	-- VERIFICATO (due crash del 07.10.2026): vendere veicoli e togliere il loro deposito nello stesso momento, o togliere
	-- binari e la stazione a cui sono attaccati insieme, corrompe lo stato del gioco. "Annulla" lavora a fasi, una per
	-- chiamata: 1) veicoli e linee; 2) binari; 3) costruzioni. Se resta qualcosa, risponde done = false e va richiamato.
	-- solo entita' ancora del tipo giusto e del giocatore: a gioco in corso gli id liberati vengono riusati subito
	-- (VERIFICATO 09.10.2026: dopo la fase dei binari restavano "binari esistenti" che non erano piu' binari)
	local CT = api.type.ComponentType
	local player = api.engine.util.getPlayer()
	local function mine(x) local po = CC.comp(x, CT.PLAYER_OWNED); return po ~= nil and po.player == player end
	local existing = function(list, kind)
		local o = {}
		for _, x in ipairs(list or {}) do
			if api.engine.entityExists(x) then
				local good
				if kind == "track" then
					local be = CC.comp(x, CT.BASE_EDGE)
					good = be ~= nil and tostring(be.roadTemplate):find("/track/", 1, true) ~= nil
				else
					good = CC.comp(x, CT.CONSTRUCTION) ~= nil and mine(x)
				end
				if good then o[#o + 1] = x end
			end
		end
		return o
	end
	local tracks = existing(c.tracks, "track")
	local cons = existing(c.constructions, "construction")
	if sold > 0 or nL > 0 then
		log[#log + 1] = "fase 1 fatta (veicoli e linee): binari e costruzioni al prossimo annulla"
		return { ok = true, done = (#tracks == 0 and #cons == 0), log = log, errors = e1 }
	end
	if #tracks > 0 then
		local okE, nE = CC.removeEdges(tracks)
		log[#log + 1] = tostring(okE and nE or 0) .. " tratti di binario rimossi; costruzioni al prossimo annulla"
		return { ok = okE ~= false, done = #cons == 0, log = log, errors = e1 }
	end
	local nC = 0
	for i = #cons, 1, -1 do
		if CC.removeConstruction(cons[i]) then nC = nC + 1 else log[#log + 1] = "costruzione " .. cons[i] .. " non rimossa" end
	end
	log[#log + 1] = nC .. " costruzioni rimosse"
	if c.roads and #c.roads > 0 then log[#log + 1] = #c.roads .. " tratti di strada lasciati (non si annullano)" end
	return { ok = true, done = true, log = log, errors = e1 }
end
-- ===================================================================== fine b2
-- ===================================================================== BOZZA (NON TESTATO) - b3 ferrovia
-- Posizionamento delle stazioni con criterio (bacino), collegamento comune tra stazioni, treni merci.
-- La logica dei binari e' quella gia' verificata di build_rail_line, spostata in funzioni riusabili.

local function unit(x, y) local l = math.sqrt(x * x + y * y); if l < 1e-6 then return 1, 0 end return x / l, y / l end

-- Posti candidati per una stazione (come in build_rail_line): giri attorno a center a distanze R e angoli
-- rispetto alla direzione (dx, dy); controlli: dislivello, binari in piano, uscite libere verso i vicini,
-- niente acqua, niente strade oltre gli estremi.
function CC.railSiteCandidates(center, dx, dy, neighbors, pass, Rs)
	local maxDz, beyond = pass[1], pass[2]
	local zRef = CC.heightAt(center.x, center.y) or center.z or 0
	local out = {}
	for _, R in ipairs(Rs) do
		for _, ang in ipairs({ 90, -90, 60, -60, 120, -120, 30, -30, 150, -150, 0, 180 }) do
			local r = math.rad(ang)
			local ox, oy = dx * math.cos(r) - dy * math.sin(r), dx * math.sin(r) + dy * math.cos(r)
			local cx, cy = center.x + ox * R, center.y + oy * R
			local hC = CC.heightAt(cx, cy) or zRef
			local hA = CC.heightAt(cx - dx * 90, cy - dy * 90) or hC
			local hB = CC.heightAt(cx + dx * 90, cy + dy * 90) or hC
			local flatOk = math.abs(hC - zRef) <= maxDz and (maxDz > 1e8 or math.abs(hA - hB) <= 6)
			local exitsOk = true
			if flatOk then
				for _, nb in ipairs(neighbors) do
					local s = ((nb.x - cx) * dx + (nb.y - cy) * dy) >= 0 and 1 or -1
					local ex, ey = cx + s * dx * 90, cy + s * dy * 90
					local tx, ty = unit(nb.x - ex, nb.y - ey)
					local mx, my = ex + (s * dx * 0.6 + tx * 0.4) * 400, ey + (s * dy * 0.6 + ty * 0.4) * 400
					if not CC.pathClear(ex, ey, mx, my, 10) then exitsOk = false end
				end
			end
			if flatOk and exitsOk and CC.inMap(cx, cy, 400) and not CC.onWater(cx, cy) and CC.railClearance(cx, cy, dx, dy, 100, beyond) then
				out[#out + 1] = { x = cx, y = cy, R = R, ang = ang }
			end
		end
	end
	return out
end

-- Costruisce una stazione a 2 binari vicino a center.
-- opts.score(x, y) -> numero (piu' alto = meglio; default: piu' vicino), opts.accept(built) -> ok, motivo
-- (se no la stazione viene tolta e si prova il posto successivo), opts.modules: moduli al posto di quelli
-- passeggeri, opts.Rs: distanze, opts.maxTries: costruzioni tentate al massimo.
function CC.placeRailStation(center, dx, dy, neighbors, name, opts)
	opts = opts or {}
	local tries, reasons = 0, {}
	local passes = { { 12, 250 }, { 30, 250 }, { 12, 140 }, { 30, 140 }, { 1e9, 140 } }
	for _, pass in ipairs(passes) do
		local cands = CC.railSiteCandidates(center, dx, dy, neighbors, pass, opts.Rs or { 350, 500, 650, 800, 1000 })
		for _, c in ipairs(cands) do c.score = opts.score and opts.score(c.x, c.y) or -c.R end
		table.sort(cands, function(p, q) return p.score > q.score end)
		for _, c in ipairs(cands) do
			if tries >= (opts.maxTries or 12) then return nil, reasons end
			tries = tries + 1
			local ok, info
			if opts.builder then
				-- costruttore su misura (es. CC.buildRailStationN: piu' binari, lunghezza variabile, b5)
				local okP, a, b = pcall(opts.builder, c.x, c.y, dx, dy)
				if okP then ok, info = a, b else ok, info = false, { error = tostring(a) } end
			elseif opts.modules then
				local orig = CC.railStationModules
				CC.railStationModules = function() return opts.modules end
				local okP, a, b = pcall(CC.buildRailStation, c.x, c.y, dx, dy, { name = name, tracks = 2 })
				CC.railStationModules = orig
				if okP then ok, info = a, b else ok, info = false, { error = tostring(a) } end
			else
				ok, info = CC.buildRailStation(c.x, c.y, dx, dy, { name = name, tracks = 2 })
			end
			if ok and info.group and #info.ends == (opts.expectEnds or 2) then
				local good, why = true, nil
				if opts.accept then good, why = opts.accept(info) end
				if good then info.site = c; return info, reasons end
				reasons[#reasons + 1] = "posto scartato: " .. tostring(why)
				CC.safeRemove(info.construction, info.edges)
			elseif ok then
				-- costruita ma non come serve (es. estremi dei binari non riconosciuti): la tolgo
				reasons[#reasons + 1] = "stazione costruita con " .. #(info.ends or {}) .. " estremi invece di " .. (opts.expectEnds or 2) .. ": rimossa"
				CC.safeRemove(info.construction, info.edges)
			elseif info and info.error then
				reasons[#reasons + 1] = tostring(info.error)
			end
		end
	end
	return nil, reasons
end

-- Binari tra stazioni consecutive (con forme di curva diverse, deviazioni, ripiego dall'alta velocita'),
-- deposito dietro un estremo libero, controllo dei percorsi con la modalita' del treno.
-- stations: lista di info di buildRailStation (con .town facoltativo). Ritorna ok, { depot, mode, loco } o false, errore.
-- opts.waitLoops = { [indice stazione] = true }: binario d'attesa/incrocio appena fuori da quella stazione (b6),
-- per i treni che arrivano quando i binari della stazione sono occupati.
function CC.linkStations(stations, log, builtEdges, built, loco, opts)
	opts = opts or {}
	local TM = api.type.enum.TransportMode
	local function endToward(st, x, y)
		local best, bv
		for _, e in ipairs(st.ends) do
			local v = (x - e.x) * e.dx + (y - e.y) * e.dy
			if not bv or v > bv then best, bv = e, v end
		end
		return best
	end
	local used = {}
	for i = 1, #stations - 1 do
		local sa, sb = stations[i], stations[i + 1]
		local pa, pb = CC.posOf(sb.group), CC.posOf(sa.group)
		local ea, eb = endToward(sa, pa.x, pa.y), endToward(sb, pb.x, pb.y)
		if used[ea.node] or used[eb.node] then return false, "orientamento delle stazioni non compatibile" end
		used[ea.node] = true; used[eb.node] = true
		for _, w in ipairs({ { i, "a" }, { i + 1, "b" } }) do
			if opts.waitLoops and opts.waitLoops[w[1]] then
				-- piu' lunghezze; se non c'e' spazio si va avanti SENZA binario d'attesa (avviso: un treno solo)
				-- (VERIFICATO p14 09.10.2026: 400 m dritti fuori dallo scalo -> "prolungamento rifiutato")
				local okW, W
				for _, wl in ipairs({ opts.waitLen or 400, 250, 160 }) do
					okW, W = CC.buildPassingLoop(w[2] == "a" and ea or eb, wl)
					if okW then break end
					-- pezzi gia' fatti (diramazione, un ramo): via subito, cosi' l'estremo della stazione torna libero
					if W.edges and #W.edges > 0 and not CC.removeEdges(W.edges) then
						for _, e in ipairs(W.edges) do builtEdges[#builtEdges + 1] = e end
						break
					end
				end
				if okW then
					for _, e in ipairs(W.edges) do builtEdges[#builtEdges + 1] = e end
					if w[2] == "a" then ea = W.exit else eb = W.exit end
					log[#log + 1] = "binario d'attesa fuori dalla stazione " .. w[1] .. (W.warning and (" (" .. W.warning .. ")") or "")
				else
					opts.waitLoopsFailed = (opts.waitLoopsFailed or 0) + 1
					log[#log + 1] = "binario d'attesa alla stazione " .. w[1] .. " non costruito: " .. tostring(W.error)
				end
			end
		end
		local ok, info
		for _, kf in ipairs({ 0.9, 0.5, 1.4, 0.3 }) do
			ok, info = CC.buildCurvedTrack(ea, eb, 60, false, kf)
			if ok or not info.retry then break end
			log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": " .. tostring(info.error) .. ", provo un altro tracciato"
		end
		if not ok and info.retry and not CC.SKIP_DETOUR then
			ok, info = railDetour(ea, eb, log, "binario " .. i .. "-" .. (i + 1))
		end
		if not ok and not CC.trackOverride and CC.railEra().track == "high_speed" and not tostring(info.error):find("acqua", 1, true) then
			CC.trackOverride = "standard"
			log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": alta velocita' rifiutata, uso binario standard"
			ok, info = CC.buildCurvedTrack(ea, eb, 60, false)
		end
		if not ok then
			local msg = tostring(info.error)
			if info.detail and info.detail.msg then msg = msg .. " (" .. table.concat(info.detail.msg, "; ") .. ")" end
			return false, "binario " .. i .. "-" .. (i + 1) .. ": " .. msg
		end
		for _, e in ipairs(info.edges or {}) do builtEdges[#builtEdges + 1] = e end
		log[#log + 1] = "binario " .. i .. "-" .. (i + 1) .. ": " .. tostring(info.length) .. " m, " .. (info.bridges or 0) .. " su ponte, "
			.. (info.tunnels or 0) .. " in galleria, " .. (info.crossings or 0) .. " passaggi a livello, "
			.. (info.overpasses or 0) .. " sovrappassi, " .. (info.underpasses or 0) .. " sottopassi"
	end
	return CC.finishRailLink(stations, used, log, built, loco, { builtEdges = builtEdges })
end

-- Testo di un errore di proposta con i dettagli del gioco (D.detail: tabella o testo).
function CC.errText(D)
	if type(D) ~= "table" then return tostring(D) end
	local t = tostring(D.error)
	local det = D.detail
	if type(det) == "table" then
		local parts = {}
		local function add(x)
			if type(x) == "table" then for _, y in pairs(x) do add(y) end else parts[#parts + 1] = tostring(x) end
		end
		add(det)
		if #parts > 0 then t = t .. " (" .. table.concat(parts, "; ") .. ")" end
	elseif det then
		t = t .. " (" .. tostring(det) .. ")"
	end
	return t
end

-- Area libera da strade, binari e costruzioni entro r metri da (x, y)?
function CC.areaClear(x, y, r)
	local CT = api.type.ComponentType
	if not CC.inMap(x, y, r + 50) then return false end
	local clear = true
	pcall(function()
		if #CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE)) > 0 then clear = false end
		if #CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.CONSTRUCTION)) > 0 then clear = false end
	end)
	return clear
end

-- Deposito su un estremo libero: prima direttamente, poi (se urta qualcosa) in fondo a un binario d'accesso (CC.leadTrack,
-- b6). VERIFICATO (p24): il deposito urta il binario accanto o una strada; il binario d'accesso si costruisce solo dove
-- l'area del deposito (circa 45 m oltre l'estremo) risulta libera, per non lasciare avanzi inutili.
function CC.depotAtEndSafe(E, name, builtEdges, log)
	log = log or {}
	local okD, D = CC.buildRailDepotAtEnd(E, name)
	if okD then return true, D end
	log[#log + 1] = "deposito sull'estremo: " .. CC.errText(D)
	if not CC.leadTrack then return false, D end
	for _, v in ipairs({ { 120, 25 }, { 200, 45 }, { 300, 70 } }) do
		for _, side in ipairs({ 1, -1 }) do
			local nx, ny = -E.dy * side, E.dx * side
			local ex, ey = E.x + E.dx * v[1] + nx * v[2], E.y + E.dy * v[1] + ny * v[2]
			if CC.areaClear(ex + E.dx * 50, ey + E.dy * 50, 35) then
				local okL, Lt = CC.leadTrack(E, v[1], v[2], side)
				if okL then
					for _, e in ipairs(Lt.edges or {}) do if builtEdges then builtEdges[#builtEdges + 1] = e end end
					local ok2, D2 = CC.buildRailDepotAtEnd(Lt.endInfo, name)
					if ok2 then log[#log + 1] = "deposito in fondo a un binario d'accesso di " .. v[1] .. " m"; return true, D2 end
					log[#log + 1] = "deposito sul binario d'accesso: " .. CC.errText(D2)
					return false, D2
				end
				log[#log + 1] = "binario d'accesso " .. v[1] .. " m: " .. tostring(Lt.error)
			end
		end
	end
	log[#log + 1] = "nessuna area libera per il deposito vicino all'estremo"
	return false, D
end

-- Deposito ferroviario su una diramazione corta dal binario del giocatore piu' vicino a p (entro 700 m): serve quando
-- non ci sono estremi liberi (anello chiuso, stazioni passanti). La diramazione resta anche se il deposito e' rifiutato
-- (pulizia prudente). DA VERIFICARE in gioco.
function CC.railDepotByBranch(p, name, builtEdges, log)
	log = log or {}
	if not (p and CC.branchFromTrack and CC.nearestTrack) then return false, { error = "diramazione non disponibile" } end
	-- tratto di binario a 250-700 m dalla stazione (lontano dagli scambi), fuori dalle costruzioni, non su ponte/galleria
	local CT = api.type.ComponentType
	local cands = {}
	pcall(function()
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 700, CT.BASE_EDGE))) do
			local be = CC.comp(e, CT.BASE_EDGE)
			if be and tostring(be.roadTemplate):find("/track/", 1, true) and be.type == 0 and #CC.each(be.objects) == 0
				and not (CC.inConstruction and CC.inConstruction(e)) then
				local mx, my = (be.position0.x + be.position1.x) / 2, (be.position0.y + be.position1.y) / 2
				local d = math.sqrt((mx - p.x) ^ 2 + (my - p.y) ^ 2)
				if d >= 250 then cands[#cands + 1] = { edge = e, sv = 0.5, d = d } end
			end
		end
	end)
	table.sort(cands, function(a, b) return a.d < b.d end)
	local tr = cands[1] or CC.nearestTrack(p.x, p.y, 700)
	if not tr then return false, { error = "nessun binario del giocatore vicino" } end
	for _, side in ipairs({ 1, -1 }) do
		-- VERIFICATO (p10): con la diramazione a 12 m di lato il deposito urta il binario principale; 35 m su 160 m
		local okB, B = CC.branchFromTrack(tr.edge, tr.sv, side, 160, 35)
		if okB then
			for _, e in ipairs(B.edges or {}) do if builtEdges then builtEdges[#builtEdges + 1] = e end end
			local okD, D = CC.buildRailDepotAtEnd(B.endInfo, name)
			if okD then
				log[#log + 1] = "deposito su una diramazione del binario (nessun estremo libero)"
				return true, D
			end
			log[#log + 1] = "deposito sulla diramazione: " .. CC.errText(D)
			return false, D
		end
		log[#log + 1] = "diramazione per il deposito: " .. tostring(B.error)
	end
	return false, { error = "diramazione rifiutata" }
end

-- Parte finale comune a tutti i collegamenti ferroviari: deposito su un estremo libero della prima o dell'ultima
-- stazione (o su opts.depotEnd), scelta della locomotiva, controllo dei percorsi deposito -> stazioni e tra stazioni.
function CC.finishRailLink(stations, used, log, built, loco, opts)
	opts = opts or {}
	used = used or {}
	local TM = api.type.enum.TransportMode
	local depot
	if opts.depotEnd then
		local okD, D = CC.depotAtEndSafe(opts.depotEnd, opts.depotName or "Deposito ferroviario", opts.builtEdges, log)
		if okD then depot = D.depot; built[#built + 1] = D.construction end
	end
	local order = { 1, #stations }
	for k = 2, #stations - 1 do order[#order + 1] = k end
	for _, si in ipairs(order) do
		for _, e in ipairs(stations[si].ends) do
			if not used[e.node] and not depot then
				local okD, D = CC.depotAtEndSafe(e, "Deposito " .. (CC.nameOf(stations[si].town or stations[si].group) or ""), opts.builtEdges, log)
				if okD then depot = D.depot; used[e.node] = true; built[#built + 1] = D.construction end
			end
		end
	end
	-- nessun estremo libero (anello chiuso, stazioni passanti): deposito su una diramazione corta
	if not depot then
		for _, si in ipairs({ 1, #stations }) do
			if depot then break end
			local okD, D = CC.railDepotByBranch(CC.posOf(stations[si].group), "Deposito " .. (CC.nameOf(stations[si].town or stations[si].group) or ""), opts.builtEdges, log)
			if okD then depot = D.depot; built[#built + 1] = D.construction end
		end
	end
	if not depot then return false, "deposito ferroviario non costruito" end
	loco = loco or CC.pickLocomotive(CC.railEra().catenary)
	if not loco then return false, "nessuna locomotiva disponibile quest'anno" end
	local mode = loco.electric and TM.ELECTRIC_TRAIN or TM.TRAIN
	local dOut = CC.depotNodes(depot)
	local g1, gN = stations[1].group, stations[#stations].group
	if not CC.hasPath(dOut, CC.stopNodeId(g1), { mode }) and not CC.hasPath(dOut, CC.stopNodeId(gN), { mode }) then
		return false, "il deposito non raggiunge le stazioni" .. (loco.electric and " (treno elettrico)" or "")
	end
	local nPairs = opts.ring and #stations or (#stations - 1)
	for i = 1, nPairs do
		local j = i % #stations + 1
		if not CC.hasPath(CC.stopNodeId(stations[i].group), CC.stopNodeId(stations[j].group), { mode }) then
			return false, "binari costruiti ma i treni non trovano il percorso " .. i .. "-" .. j
		end
		if opts.bothWays and not CC.hasPath(CC.stopNodeId(stations[j].group), CC.stopNodeId(stations[i].group), { mode }) then
			return false, "binari costruiti ma i treni non trovano il percorso " .. j .. "-" .. i .. " (verso opposto)"
		end
	end
	return true, { depot = depot, mode = mode, loco = loco }
end

-- ---------------------------------------------------------------- stazione merci
-- Scalo merci: schema verificato copiato da uno costruito a mano (1 binario, 160 m: vedi CC.railStationModulesN, b5).
-- Ritorna il costruttore da passare a CC.placeRailStation.
function CC.cargoStationBuilder(name)
	return function(x, y, ddx, ddy)
		return CC.buildRailStationN(x, y, ddx, ddy, { layout = "PT", segments = 4, kind = "cargo", name = name })
	end
end
function CC.cargoStationModules(e)
	return CC.railStationModulesN(e, "PT", 4, "cargo")
end
CC.CARGO_MAX_TRAIN_LEN = 150   -- scalo da 160 m

-- Treno merci (locomotiva + carri per la merce) entro la lunghezza dello scalo, assegnato alla linea.
function CC.buyCargoTrain(depot, line, cargo, nCars, loco, stopIndex)
	loco = loco or CC.pickLocomotive(CC.railEra().catenary)
	if not loco then return false, "nessuna locomotiva disponibile" end
	local models, miss = CC.trainModels(loco, nCars or 4, { cargo }, CC.CARGO_MAX_TRAIN_LEN)
	if #miss > 0 then return false, "nessun carro per: " .. table.concat(miss, ", ") end
	local ok, veh, warn = CC.buyComposition(depot, models, line, stopIndex or 0)
	if not ok then return false, tostring(veh) end
	return true, { vehicle = veh, cars = #models - 1, warning = warn }
end

-- Punto da cui si cerca il posto per lo scalo: la stazione per camion integrata dell'industria (TF3: e' il punto di
-- carico della merce), altrimenti la posizione dell'industria (VERIFICATO p4 09.10.2026: per una fattoria la posizione
-- dell'industria e' lontana dal bacino: 10 posti scartati). Per citta' e altro: CC.posOf.
function CC.industryAnchor(e)
	if CC.comp(e, api.type.ComponentType.INDUSTRY) then
		local g = CC.industryRoadStation(e)
		local p = g and CC.posOf(g)
		if p then return p end
	end
	return CC.posOf(e)
end

-- Merce che l'industria ind produce e che target (industria o citta') usa: cargo, oppure nil, errore.
-- (VERIFICATO p4 09.10.2026: mancava, la linea merci si fermava con "attempt to call field 'cargoFor'")
function CC.cargoFor(ind, target)
	local CT = api.type.ComponentType
	if not CC.comp(ind, CT.INDUSTRY) then return nil, tostring(ind) .. " non e' un'industria" end
	local _, outs = CC.industryCargo(ind)
	if #outs == 0 then return nil, (CC.nameOf(ind) or "l'industria") .. " non produce merci" end
	if CC.comp(target, CT.INDUSTRY) then
		local ins = CC.industryCargo(target)
		for _, o in ipairs(outs) do
			for _, i in ipairs(ins) do if o == i then return o end end
		end
		return nil, (CC.nameOf(target) or "la destinazione") .. " non usa le merci di " .. (CC.nameOf(ind) or "questa industria")
	elseif CC.comp(target, CT.TOWN) then
		local accepted = {}
		pcall(function()
			for _, list in pairs(api.engine.util.town.getLandUse2CargoTypes()) do
				for _, id in ipairs(CC.each(list)) do accepted[id] = true end
			end
		end)
		for _, o in ipairs(outs) do if accepted[o] then return o end end
		local names = {}
		for _, o in ipairs(outs) do names[#names + 1] = CC.cargoName(o) end
		return nil, "le citta' non accettano " .. table.concat(names, ", ") .. ": va portato prima a un'industria che le lavora"
	end
	return nil, tostring(target) .. " non e' ne' una citta' ne' un'industria"
end

-- ---------------------------------------------------------------- linea ferroviaria merci
-- Stazione merci vicino all'industria (deve "vedere" l'industria nel bacino), stazione all'arrivo (industria o
-- citta'), binari, deposito, linea e treni merci. Se fallisce, toglie quello che ha costruito.
local function buildCargoRail(a, built, builtEdges)
	local CT = api.type.ComponentType
	local ind, target = a.industry_id, a.target_id
	if not CC.comp(ind, CT.INDUSTRY) then return { ok = false, error = tostring(ind) .. " non e' un'industria" } end
	local cargo, err = CC.cargoFor(ind, target)
	if not cargo then return { ok = false, error = err } end
	local mods, merr = CC.cargoStationModules()
	if not mods then return { ok = false, error = merr } end
	local n1 = (CC.nameOf(ind) or "Industria") .. " scalo merci"
	local n2 = (CC.nameOf(target) or "Arrivo") .. " scalo merci"
	local P1, P2 = CC.industryAnchor(ind), CC.industryAnchor(target)
	if not P1 or not P2 then return { ok = false, error = "posizione di partenza o arrivo non trovata" } end
	local dx, dy = unit(P2.x - P1.x, P2.y - P1.y)
	local log, stations = {}, {}
	-- partenza: piu' vicina possibile all'industria, e l'industria deve essere nel bacino
	local s1, why1 = CC.placeRailStation(P1, dx, dy, { P2 }, n1, {
		builder = CC.cargoStationBuilder(n1), Rs = { 120, 180, 250, 350, 500 }, maxTries = 10,
		score = function(x, y) return -math.sqrt((x - P1.x) ^ 2 + (y - P1.y) ^ 2) end,
		accept = function(info)
			if CC.stationCatches(info.station, ind) then return true end
			return false, "l'industria non e' nel bacino"
		end,
	})
	if not s1 then return { ok = false, error = "nessun posto per lo scalo merci vicino all'industria", log = why1 } end
	built[#built + 1] = s1.construction
	for _, e in ipairs(s1.edges or {}) do builtEdges[#builtEdges + 1] = e end
	stations[1] = s1
	-- arrivo
	local isTown = CC.comp(target, CT.TOWN) ~= nil
	local s2, why2 = CC.placeRailStation(P2, -dx, -dy, { P1 }, n2, {
		builder = CC.cargoStationBuilder(n2), Rs = isTown and { 250, 350, 500, 650 } or { 120, 180, 250, 350, 500 }, maxTries = 10,
		score = isTown and function(x, y) return CC.townBuildingsNear(x, y, 300) end
			or function(x, y) return -math.sqrt((x - P2.x) ^ 2 + (y - P2.y) ^ 2) end,
		accept = function(info)
			if isTown then
				if #CC.stationCatchables(info.station) > 0 then return true end
				return false, "nessun edificio nel bacino"
			end
			if CC.stationCatches(info.station, target) then return true end
			return false, "l'industria di arrivo non e' nel bacino"
		end,
	})
	if not s2 then return { ok = false, error = "nessun posto per lo scalo merci all'arrivo", log = why2 } end
	built[#built + 1] = s2.construction
	for _, e in ipairs(s2.edges or {}) do builtEdges[#builtEdges + 1] = e end
	stations[2] = s2
	local okL, link = CC.linkStations(stations, log, builtEdges, built)
	if not okL then return { ok = false, error = link, log = log } end
	local okLine, li = CC.createLine(a.name or (CC.cargoName(cargo) .. " in treno: " .. (CC.nameOf(ind) or "") .. " - " .. (CC.nameOf(target) or "")), { s1.group, s2.group })
	if not okLine then return { ok = false, error = li.error, log = log } end
	local trains, errs = {}, {}
	-- binario unico e scali a 1 binario: un solo treno (due si bloccherebbero); per piu' treni build_cargo_rail_network
	local nT = 1
	for k = 1, nT do
		local okT, T = CC.buyCargoTrain(link.depot, li.line, cargo, math.max(1, math.min(10, a.num_cars or 4)), link.loco, CC.staggerStop(k, nT, 2))
		if okT then trains[#trains + 1] = T.vehicle else errs[#errs + 1] = T end
	end
	return { ok = #trains > 0 and #errs == 0, line_id = li.line, stations = { s1.group, s2.group }, depot_id = link.depot,
		trains = trains, cargo = CC.cargoName(cargo), errors = errs, log = log }
end

SIM_ACTIONS.build_cargo_rail_line = function(a)
	CC.need(a, { industry_id = "int", target_id = "int", num_trains = "int?", num_cars = "int?", name = "str?" })
	local built, builtEdges = {}, {}
	CC.trackOverride = nil
	local ok, r = pcall(buildCargoRail, a, built, builtEdges)
	if not ok then r = { ok = false, error = tostring(r) } end
	if not r.ok and not r.line_id then
		r.cleanup, r.leftovers = CC.rollback(built, builtEdges)
	end
	CC.trackOverride = nil
	return r
end

-- ---------------------------------------------------------------- ferrovia passeggeri v2
-- Come build_rail_line, ma ogni stazione va nel posto con piu' edifici nel bacino (non solo il primo libero)
-- e, se richiesto (feeder = true, default), ogni stazione viene collegata al centro con una navetta bus.
-- Opzioni nuove (b5/b6/b7, DA VERIFICARE in gioco):
--   double_track = true: doppio binario tra le stazioni (un binario per senso, segnali a senso unico);
--   express_town_ids = { ... }: linea veloce che ferma solo in queste citta' (sottoinsieme di town_ids); nelle altre
--     stazioni c'e' un binario di transito per non fermarsi dietro ai regionali;
--   express_trains = n: treni della linea veloce (default 1).
-- Le fermate vanno avanti e indietro (A, B, C, B): senza, il treno tornerebbe da C ad A senza fermarsi in B.
local function buildRailLine2(a, built, builtEdges)
	local towns = a.town_ids
	if #towns < 2 then return { ok = false, error = "servono almeno 2 citta'" } end
	local express = {}
	for _, t in ipairs(a.express_town_ids or {}) do express[t] = true end
	local hasExpress = next(express) ~= nil
	local special = a.double_track or hasExpress
	local C = {}
	for i, t in ipairs(towns) do C[i] = townCenter(t) end
	local log, stations, notes = {}, {}, {}
	local nCars = a.num_cars or 3
	local trainLen = CC.estimateTrainLength and CC.estimateTrainLength(nCars) or 120
	for i, t in ipairs(towns) do
		local dx, dy
		if i == 1 then dx, dy = unit(C[2].x - C[1].x, C[2].y - C[1].y)
		elseif i == #towns then dx, dy = unit(C[i].x - C[i - 1].x, C[i].y - C[i - 1].y)
		else
			local ax, ay = unit(C[i].x - C[i - 1].x, C[i].y - C[i - 1].y)
			local bx, by = unit(C[i + 1].x - C[i].x, C[i + 1].y - C[i].y)
			dx, dy = unit(ax + bx, ay + by)
		end
		local nbs = {}
		if C[i - 1] then nbs[#nbs + 1] = C[i - 1] end
		if C[i + 1] then nbs[#nbs + 1] = C[i + 1] end
		local tname = CC.nameOf(t) or ("citta' " .. i)
		local score = function(x, y) return CC.townBuildingsNear(x, y, 300) * 10 - math.sqrt((x - C[i].x) ^ 2 + (y - C[i].y) ^ 2) / 100 end
		local st, why
		if special then
			local skip = hasExpress and not express[t]
			local plan = CC.planStation({ kind = "passengers", lines = (hasExpress and express[t]) and 2 or 1,
				trains = (a.num_trains or 1) + ((hasExpress and express[t]) and (a.express_trains or 1) or 0),
				train_len = trainLen, double = a.double_track, through = skip and 1 or 0,
				terminal = (i == 1 or i == #towns) })
			local info
			st, info = CC.placeStationSmart(C[i], dx, dy, nbs, tname .. " stazione", plan, { score = score })
			if not st then return { ok = false, error = "non trovo spazio per la stazione di " .. tname, log = info and info.steps, alternatives = info and info.alternatives, reuse_group = info and info.reuse_group } end
			if info.needs_feeder then notes[#notes + 1] = tname .. ": stazione lontana dal centro, serve la navetta" end
			if info.shorter then notes[#notes + 1] = tname .. ": stazione accorciata a " .. info.plan.length .. " m (treni al massimo " .. info.max_train_len .. " m)"; trainLen = math.min(trainLen, info.max_train_len) end
			st.plan = info.plan
		else
			st, why = CC.placeRailStation(C[i], dx, dy, nbs, tname .. " stazione", { score = score })
			if not st then return { ok = false, error = "non trovo spazio per la stazione di " .. tname, log = why } end
		end
		st.town = t
		stations[i] = st
		built[#built + 1] = st.construction
		for _, e in ipairs(st.edges or {}) do builtEdges[#builtEdges + 1] = e end
		log[#log + 1] = tname .. ": stazione a " .. st.site.R .. " m dal centro, " .. CC.townBuildingsNear(st.site.x, st.site.y, 300) .. " edifici entro 300 m"
			.. (st.plan and (", " .. st.plan.tracks .. " binari + " .. st.plan.through .. " di transito, " .. st.plan.length .. " m") or "")
	end
	local okL, link
	if a.double_track then
		okL, link = CC.linkStationsDouble(stations, log, builtEdges, built)
	else
		okL, link = CC.linkStations(stations, log, builtEdges, built)
	end
	if not okL then return { ok = false, error = link, log = log } end
	local groups = {}
	for i, st in ipairs(stations) do groups[i] = st.group end
	local okLine, li = CC.createLine(a.name or "Treno", CC.lineStopOrder(groups, "back_forth"))
	if not okLine then return { ok = false, error = li.error, log = log } end
	local nTrains = math.max(1, math.min(a.double_track and 2 * #stations or #stations, a.num_trains or 1))
	local trains, errs = {}, {}
	local nStops = #CC.lineStopOrder(groups, "back_forth")
	for k = 1, nTrains do
		local okT, T = CC.buyPassengerTrain(link.depot, li.line, nCars, CC.staggerStop(k, nTrains, nStops), trainLen, link.loco)
		if okT then trains[#trains + 1] = T.vehicle else errs[#errs + 1] = T.error end
	end
	local result = { ok = #trains > 0 and #errs == 0, line_id = li.line, stations = groups, depot_id = link.depot, trains = trains, errors = errs, log = log, notes = notes }
	-- linea veloce: solo le citta' indicate, sugli stessi binari
	if hasExpress then
		local eg = {}
		for i, t in ipairs(towns) do if express[t] then eg[#eg + 1] = groups[i] end end
		if #eg >= 2 then
			local okE, le = CC.createLine((a.name or "Treno") .. " veloce", CC.lineStopOrder(eg, "back_forth"))
			if okE then
				result.express_line_id = le.line
				result.line_ids = { li.line, le.line }
				local nE = math.max(1, math.min(4, a.express_trains or 1))
				for k = 1, nE do
					local okT, T = CC.buyPassengerTrain(link.depot, le.line, nCars, CC.staggerStop(k, nE, 2 * #eg - 2), trainLen, link.loco)
					if okT then trains[#trains + 1] = T.vehicle else errs[#errs + 1] = "veloce: " .. tostring(T.error) end
				end
			else
				errs[#errs + 1] = "linea veloce non creata"
			end
		else
			errs[#errs + 1] = "linea veloce: servono almeno 2 citta' tra quelle della linea"
		end
		result.ok = #trains > 0 and #errs == 0
	end
	-- nodi di scambio: navetta bus stazione - centro (gli errori non fanno fallire la linea)
	if a.feeder ~= false then
		for i, st in ipairs(stations) do
			local okF, F = pcall(SIM_ACTIONS.connect_station_to_town, { station_id = st.group, town_id = towns[i], num_vehicles = 1 })
			log[#log + 1] = (CC.nameOf(towns[i]) or "?") .. ": navetta " .. ((okF and F.ok) and ("linea " .. tostring(F.line_id)) or ("non creata (" .. tostring(okF and F.error or F) .. ")"))
		end
	end
	return result
end

SIM_ACTIONS.build_rail_line2 = function(a)
	CC.need(a, { town_ids = "ids", num_trains = "int?", num_cars = "int?", name = "str?", double_track = "bool?",
		express_town_ids = "ids?", express_trains = "int?", feeder = "bool?" })
	local built, builtEdges = {}, {}
	CC.trackOverride = nil
	local ok, r = pcall(buildRailLine2, a, built, builtEdges)
	if not ok then r = { ok = false, error = tostring(r) } end
	if not r.ok and not r.line_id then
		r.cleanup, r.leftovers = CC.rollback(built, builtEdges)
	end
	r.era = CC.railEra()
	r.era.track_used = CC.trackOverride or r.era.track
	CC.trackOverride = nil
	return r
end
-- ===================================================================== fine b3
-- ===================================================================== BOZZA (NON TESTATO) - b4 aerei, elicotteri, navi, superstrade
-- Queste costruzioni non le conosciamo ancora: la strada e' la stessa usata per la stazione ferroviaria.
--   1. stasera si costruiscono A MANO un campo d'aviazione/aeroporto, un eliporto, un porto e un deposito navale;
--   2. la sonda s6 ne copia file .con, parametri e moduli;
--   3. i dati vanno in CC.TEMPLATES qui sotto e la mod li ripete dove serve.
-- Schemi riempiti il 07.10.2026 dalle costruzioni di un salvataggio di terzi (sonda s17). DA PROVARE in gioco.

CC.TEMPLATES = CC.TEMPLATES or {
	-- Copiati con la sonda s17 dal salvataggio di terzi (07.10.2026, vedi dev-notes/note/studio-salvataggio-terzi.md).
	-- half = mezza dimensione massima in metri (dal bounding box); waterSide = lato locale con acqua a 30-100 m.
	airfield = { file = "::/stations/air/airfield.con", params = { hangar = 1, terminals = 3 },
		modules = { [10001000] = { name = "::/stations/air/airfield/af_hangar.module", variant = 0 }, [10001002] = { name = "::/stations/air/airfield/af_main.module", variant = 0 }, [10001004] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 }, [10001006] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 }, [10001008] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 } },
		half = 200, kind = "air" },   -- da: Brunssum Airport
	airport = { file = "::/stations/air/airport.con", params = { dir = 2, hangar = 1, terminals = 1 },
		modules = { [1008] = { name = "::/stations/air/airport/ap_main.module", variant = 0 }, [2000] = { name = "::/stations/air/airport/ap_hangar.module", variant = 0 }, [70003] = { name = "::/stations/air/airport/ap_terminal.module", variant = 0 }, [70012] = { name = "::/stations/air/airport/ap_terminal.module", variant = 0 }, [9000] = { name = "::/stations/air/airport/airport_era_c_landing_direction.module", variant = 0 } },
		half = 330, kind = "air" },   -- da: Geldrop-Mierlo Airport
	heliport = { file = "::/stations/air/heliport.con", params = {  },
		modules = nil,
		half = 75, kind = "air", Rs = { 150, 250, 400, 600, 900 } },   -- da: Lisse Heliport (vicino al centro: bacino)
	helipad = { file = "::/stations/air/helipad.con", params = {  },
		modules = nil,
		half = 20, kind = "air", Rs = { 60, 120, 200, 300, 500 } },   -- da: Winterswijk Heliport (in citta')
	harbor = { file = "::/stations/water/harbor_modular.con", params = { smallterminals = 1 },
		modules = { [100009736] = { name = "::/stations/water/small_pier.module", variant = 0 }, [100009804] = { name = "::/stations/water/passenger_dock_50_12.module", variant = 0 }, [100010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [99010053] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [99010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 } },
		half = 40, kind = "water", waterSide = "-Y" },   -- da: Hilversum Port #1
	harbor_large = { file = "::/stations/water/harbor_modular.con", params = { largeterminals = 1 },
		modules = { [100009444] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [100009612] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [100009722] = { name = "::/stations/water/passenger_dock_100_50.module", variant = 0 }, [100010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [101010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [102010149] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [103008547] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [103010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [105008808] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [105009608] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [87008347] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [89008608] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [89009408] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [90008345] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [90009145] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [92010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [93009855] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [93010055] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [93010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [94010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [95009611] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [95009754] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [95010055] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [95010151] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [96010151] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [97010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [98010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [99010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 } },
		half = 160, kind = "water", waterSide = "-Y" },   -- da: Hilversum Port
	water_depot = { file = "::/depots/water/water_depot.con", params = {  },
		modules = nil,
		half = 80, kind = "water", waterSide = "-Y" },   -- da: Hilversum Ship Depot
}

-- Cartelle dei veicoli (dalla sonda s4): aerei, elicotteri, navi.
CC.VEHICLE_FOLDERS = CC.VEHICLE_FOLDERS or { plane = "plane", heli = "helicopter", ship = "ship" }

local function unit2(x, y) local l = math.sqrt(x * x + y * y); if l < 1e-6 then return 1, 0 end return x / l, y / l end

-- Costruisce lo schema tpl con centro (x, y) e asse locale Y lungo (dx, dy). Ritorna ok, info { construction,
-- groups, depots } o false, errore. Passa dalla verifica a secco (CC.buildCmd).
function CC.placeTemplate(tpl, x, y, dx, dy, name)
	local CT = api.type.ComponentType
	if not CC.inMap(x, y, (tpl.half or 100) + 100) then return false, "fuori dai confini della mappa" end
	local z = CC.heightAt(x, y) or 0
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = tpl.file
	local params = { year = CC.year(), seed = 0 }
	for k, v in pairs(tpl.params or {}) do if k ~= "modules" and k ~= "year" and k ~= "seed" then params[k] = v end end
	if tpl.modules then
		local mods = {}
		for slot, m in pairs(tpl.modules) do mods[tonumber(slot) or slot] = { name = m.name, variant = m.variant or 0 } end
		params.modules = mods
	else
		params.modules = {}
	end
	ce.params = params     -- tutto insieme: il gioco copia la tabella
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(x, y, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = name or "Costruzione"
	prop.constructionsToAdd = { ce }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, tostring(cmd) end
	local ok, res, ents = CC.send(cmd)
	if not ok then
		local pe = CC.proposalErrors(res)
		local extra = ""
		-- (09.10.2026: p21 dava "rifiutata: " vuoto) eccezione del comando e messaggi della verifica a secco
		if CC._last and CC._last.exception then extra = " eccezione: " .. CC._last.exception end
		local okD, dinf = CC.dryRun(prop)
		if dinf and dinf.msg and #dinf.msg > 0 then extra = extra .. " verifica: " .. table.concat(dinf.msg, "; ") end
		if dinf and dinf.exception then extra = extra .. " verifica: " .. dinf.exception end
		return false, "rifiutata: " .. table.concat(pe.msg, "; ") .. (#pe.coll > 0 and (" (" .. #pe.coll .. " collisioni)") or "") .. extra
	end
	local out = { groups = {}, depots = {} }
	for _, e in ipairs(ents or {}) do
		local c = CC.comp(e, CT.CONSTRUCTION)
		if c then
			out.construction = out.construction or e
			for _, st in ipairs(CC.each(c.stations)) do
				local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
				if okG and g and g >= 0 then out.groups[#out.groups + 1] = g end
			end
			for _, d in ipairs(CC.each(c.depots)) do out.depots[#out.depots + 1] = d end
		end
	end
	if out.groups[1] and name then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(out.groups[1], name)) end) end
	return true, out
end

-- Strada d'accesso: nodi stradali liberi della costruzione collegati alla strada piu' vicina (entro maxD).
function CC.ensureRoadAccess(con, maxD)
	local CT = api.type.ComponentType
	local c = CC.comp(con, CT.CONSTRUCTION)
	if not c then return false, "costruzione inesistente" end
	local cand, seen = {}, {}
	for _, fn in ipairs(CC.each(c.frozenNodes)) do
		cand[#cand + 1] = fn
		for _, sg in ipairs(CC.each(api.engine.system.streetSystem.getNodeSegments(fn))) do
			local b = CC.comp(sg, CT.BASE_EDGE)
			if b then cand[#cand + 1] = b.node0; cand[#cand + 1] = b.node1 end
		end
	end
	local free = {}
	for _, n in ipairs(cand) do
		if not seen[n] then
			seen[n] = true
			local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(n))
			if #segs == 1 and CC.comp(segs[1], CT.BASE_EDGE_STREET) then free[#free + 1] = n end
		end
	end
	if #free == 0 then return true, "nessun accesso stradale libero (gia' collegata o non serve)" end
	local done = 0
	for _, n in ipairs(free) do
		local p = CC.comp(n, CT.BASE_NODE).position
		local best, bd
		for _, e in ipairs(CC.streetEdgesNear(p.x, p.y, maxD or 300, 5)) do
			local be = CC.comp(e.edge, CT.BASE_EDGE)
			for _, m in ipairs({ be.node0, be.node1 }) do
				if not seen[m] then
					local q = CC.comp(m, CT.BASE_NODE).position
					local d = math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2)
					if not bd or d < bd then best, bd = m, d end
				end
			end
		end
		if best then
			local ok = CC.connectNodes(n, best, nil, false)
			if not ok then ok = CC.connectNodes(n, best, "::/infrastructure/street/town/town_old_small.street_template", false) end
			if ok then done = done + 1 end
		end
	end
	return done > 0, done .. " accessi stradali su " .. #free
end

-- Posto piano e asciutto attorno al centro per uno schema "air" (mezza lunghezza tpl.half).
local function airSites(center, tpl, Rs)
	local out = {}
	local half = tpl.half or 100
	for _, R in ipairs(Rs) do
		for a = 0, 330, 30 do
			local r = math.rad(a)
			local x, y = center.x + math.cos(r) * R, center.y + math.sin(r) * R
			for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 0.7071, 0.7071 }, { 0.7071, -0.7071 } }) do
				local dx, dy = d[1], d[2]
				local h0 = CC.inMap(x, y, half + 150) and CC.heightAt(x, y) or nil
				local h1 = CC.heightAt(x + dx * half, y + dy * half)
				local h2 = CC.heightAt(x - dx * half, y - dy * half)
				local h3 = CC.heightAt(x + dy * half * 0.5, y - dx * half * 0.5)
				local h4 = CC.heightAt(x - dy * half * 0.5, y + dx * half * 0.5)
				if h0 and h1 and h2 and h3 and h4 then
					local mx, mn = math.max(h0, h1, h2, h3, h4), math.min(h0, h1, h2, h3, h4)
					local wet = CC.onWater(x, y) or CC.onWater(x + dx * half, y + dy * half) or CC.onWater(x - dx * half, y - dy * half)
					local clear = CC.pathClear(x - dx * half, y - dy * half, x + dx * half, y + dy * half, half * 0.3)
					if not wet and clear and mx - mn < (tpl.maxSlope or 8) then
						out[#out + 1] = { x = x, y = y, dx = dx, dy = dy, R = R, flat = mx - mn }
					end
				end
			end
		end
	end
	table.sort(out, function(p, q) if p.R ~= q.R then return p.R < q.R end return p.flat < q.flat end)
	return out
end

-- Punto di costa piu' vicino al centro: cammino verso l'esterno finche' trovo acqua. dir = verso l'acqua.
local function shoreSites(center, maxR)
	local out = {}
	for a = 0, 337.5, 22.5 do
		local r = math.rad(a)
		local dx, dy = math.cos(r), math.sin(r)
		local lastLand
		for d = 0, maxR or 3000, 25 do
			local x, y = center.x + dx * d, center.y + dy * d
			if not CC.inMap(x, y, 200) then break end
			if CC.onWater(x, y) then
				if lastLand then out[#out + 1] = { x = lastLand[1], y = lastLand[2], dx = dx, dy = dy, R = d } end
				break
			end
			lastLand = { x, y }
		end
	end
	table.sort(out, function(p, q) return p.R < q.R end)
	return out
end

-- Asse locale che deve guardare l'acqua -> orientamento (dx, dy) da passare a placeTemplate.
local function orientForWater(side, wx, wy)
	if side == "+Y" then return wx, wy end
	if side == "-Y" then return -wx, -wy end
	if side == "+X" then return -wy, wx end      -- X locale = (dy, -dx): voglio X = w  ->  d = (-wy, wx)
	if side == "-X" then return wy, -wx end
	return wx, wy
end

-- Costruisce lo schema `key` vicino alla citta'. Ritorna ok, info.
function CC.buildTemplateNear(key, town, name)
	local tpl = CC.TEMPLATES[key]
	if not tpl then return false, "schema '" .. key .. "' mancante: costruiscine uno a mano e copia i dati con la sonda s6" end
	local c = CC.posOf(town)
	if not c then return false, "citta' non trovata" end
	local tried = {}
	if tpl.kind == "water" then
		for i, s in ipairs(shoreSites(c, 4000)) do
			if i > 8 then break end
			local dx, dy = orientForWater(tpl.waterSide, s.dx, s.dy)
			local back = tpl.shoreBack or 0          -- di quanto arretrare dalla costa (dalla sonda: meta' profondita' sul terreno)
			local ok, info = CC.placeTemplate(tpl, s.x - s.dx * back, s.y - s.dy * back, dx, dy, name)
			if ok then return true, info end
			tried[#tried + 1] = info
		end
		return false, "nessun punto di costa adatto: " .. table.concat(tried, " | ")
	end
	for i, s in ipairs(airSites(c, tpl, tpl.Rs or { 500, 800, 1200, 1600, 2200 })) do
		if i > 10 then break end
		local ok, info = CC.placeTemplate(tpl, s.x, s.y, s.dx, s.dy, name)
		if ok then return true, info end
		tried[#tried + 1] = info
	end
	return false, "nessun posto piano e libero: " .. table.concat(tried, " | ")
end

-- ---------------------------------------------------------------- linee aeree / elicotteri / navi
-- kind: "airfield" | "airport" | "heliport" | "helipad" | "harbor" | "harbor_large"; cargo = true per le merci (veicoli senza posti).
SIM_ACTIONS.build_air_or_water_line = function(a)
	CC.need(a, { town_ids = "ints", kind = "str", num_vehicles = "int?", name = "str?" })
	local tpl = CC.TEMPLATES[a.kind]
	if not tpl then return { ok = false, error = "schema '" .. a.kind .. "' mancante (vedi sonda s6)" } end
	local folder = (a.kind == "heliport" or a.kind == "helipad") and CC.VEHICLE_FOLDERS.heli or (tpl.kind == "water" and CC.VEHICLE_FOLDERS.ship or CC.VEHICLE_FOLDERS.plane)
	local groups, depots, log = {}, {}, {}
	for i, t in ipairs(a.town_ids) do
		-- VERIFICATO (salvataggio di terzi): helipad.con non ha deposito, heliport.con si'. Con "helipad" la prima
		-- fermata diventa un eliporto (fa da hangar), le altre restano piazzole.
		local key = (a.kind == "helipad" and i == 1 and CC.TEMPLATES.heliport) and "heliport" or a.kind
		local ok, info = CC.buildTemplateNear(key, t, (CC.nameOf(t) or "Citta'") .. " " .. key)
		if not ok then return { ok = false, error = (CC.nameOf(t) or "?") .. ": " .. tostring(info), stations = groups, log = log } end
		if not info.groups[1] then return { ok = false, error = "costruito ma senza stazione", log = log } end
		groups[i] = info.groups[1]
		for _, d in ipairs(info.depots) do depots[#depots + 1] = d end
		local okR, msg = CC.ensureRoadAccess(info.construction, 400)
		log[#log + 1] = (CC.nameOf(t) or "?") .. ": costruito; strada d'accesso: " .. tostring(msg)
	end
	-- deposito: quello incluso nella costruzione (aeroporti) o uno schema a parte (deposito navale).
	-- VERIFICATO (prova p20): l'hangar di un campo d'aviazione puo' restare senza uscita verso le piste; si sceglie un
	-- deposito che raggiunge davvero le fermate (modi aereo/elicottero/nave).
	local MOD = { 9, 10, 11, 12, 13 }
	local depot
	for _, d in ipairs(depots) do
		local okP = false
		for _, n in ipairs(CC.groupNodes(groups[1])) do
			if CC.hasPath(CC.depotNodes(d), n, MOD) then okP = true; break end
		end
		if okP then depot = d; break end
		log[#log + 1] = "deposito " .. tostring(d) .. " senza percorso verso le fermate: scartato"
	end
	if not depot and CC.TEMPLATES.water_depot and tpl.kind == "water" then
		local ok, info = CC.buildTemplateNear("water_depot", a.town_ids[1], "Cantiere navale")
		if ok then depot = info.depots[1] else log[#log + 1] = "deposito navale: " .. tostring(info) end
	end
	-- aerei/elicotteri: ripiego su un hangar del giocatore gia' esistente dello stesso tipo (volano ovunque)
	if not depot and tpl.kind == "air" then
		local want = (folder == CC.VEHICLE_FOLDERS.heli) and "heli" or "air"
		local p0 = CC.posOf(groups[1])
		local bd
		for _, d in ipairs(CC.playerDepots()) do
			local f = d.file or ""
			local match = (want == "heli" and f:find("heliport", 1, true)) or (want == "air" and (f:find("airport", 1, true) or f:find("airfield", 1, true)))
			if match and p0 and d.x then
				local dist = (d.x - p0.x) ^ 2 + (d.y - p0.y) ^ 2
				if not bd or dist < bd then depot, bd = d.depot, dist end
			end
		end
		if depot then log[#log + 1] = "hangar esistente usato: " .. tostring(depot) end
	end
	if not depot then return { ok = false, error = "nessun deposito/hangar per i veicoli", stations = groups, log = log } end
	local okL, li = CC.createLine(a.name or ("Linea " .. a.kind), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, log = log } end
	-- VERIFICATO (sonda s4 + prova p20 sul salvataggio di terzi): gli aerei hanno modo 9 (grandi, solo aeroporto) o
	-- 11 (piccoli: campo d'aviazione e aeroporto). Sul campo d'aviazione un aereo di modo 9 non puo' essere assegnato.
	local TMe = api.type.enum.TransportMode
	local SMALL = (TMe and TMe.SMALL_AIRCRAFT) or 11
	local needMode = (a.kind == "airfield") and SMALL or nil
	local model
	api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(n)
		if n:find("/" .. folder .. "/", 1, true) then
			local id = api.res.modelRep.find(n)
			local m = api.res.modelRep.get(id)
			local av = m.metadata.availability
			local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
			local y = CC.year()
			if from <= y and (to == 0 or to > y) then
				local okMode = true
				if needMode then
					okMode = false
					pcall(function()
						for _, tm in ipairs(CC.each(m.metadata.transportVehicle.engineTransportModes)) do if tm == needMode then okMode = true end end
					end)
				end
				local pass, other = CC.modelLoads(id)
				local okLoad = (a.cargo and other > 0) or ((not a.cargo) and pass > 0)
				if okMode and okLoad and (not model or from > model.from) then model = { id = id, name = n, from = from } end
			end
		end
	end)
	if not model then return { ok = false, error = "nessun veicolo '" .. folder .. "' disponibile quest'anno", line_id = li.line, log = log } end
	local fk = (folder == CC.VEHICLE_FOLDERS.heli) and "helicopter" or (tpl.kind == "water" and "ship" or "plane")
	local n, fleet = CC.initialFleet(groups, model.id, fk, a.num_vehicles, 10)
	local okV, v = CC.buyVehicles(depot, model.id, n, li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, vehicles = v.vehicles,
		model = model.name, errors = v.errors, log = log, fleet = fleet }
end

-- ---------------------------------------------------------------- superstrade tra citta'
-- Riusa il costruttore di binari (curva, profilo, ponti, gallerie) con un tipo di strada al posto del binario e
-- TUTTI gli incroci a livelli separati (CC.MIN_CROSS_ANGLE = 91 -> ogni incrocio diventa sovrappasso/sottopasso).
-- Usa CC.CURVE_SEG_TYPE e CC.CURVE_ROAD_TYPE, aggiunti a buildCurvedTrack in cc_lib (se non impostati: binario
-- come prima). Collega due nodi di strada ai margini delle citta' (niente svincoli per ora).
local function highwayTemplate()
	if CC.HIGHWAY_TEMPLATE then return CC.HIGHWAY_TEMPLATE end
	local best
	for _, n in ipairs(CC.each(api.res.streetTemplateRep.getAll())) do
		local s = tostring(n)
		if (s:find("highway") or s:find("motorway")) and not s:find("one_way") and not s:find("/track/") then best = best or s end
	end
	return best
end

-- Estremo stradale ai margini della citta' verso un punto (capolinea o nodo di una strada verso l'esterno).
local function townRoadEnd(town, toward)
	local c = CC.posOf(town)
	local dx, dy = unit2(toward.x - c.x, toward.y - c.y)
	local best, bs
	for _, d in ipairs(CC.deadEndsNear(c.x + dx * 400, c.y + dy * 400, 700)) do
		local v = (d.x - c.x) * dx + (d.y - c.y) * dy
		if not bs or v > bs then best, bs = d, v end
	end
	if not best then return nil end
	local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(best.node))
	local be = CC.comp(segs[1], api.type.ComponentType.BASE_EDGE)
	local first = be.node0 == best.node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local tx, ty = t.x, t.y
	if first then tx, ty = -tx, -ty end
	tx, ty = unit2(tx, ty)
	return { node = best.node, x = p.x, y = p.y, z = p.z, dx = tx, dy = ty }
end

SIM_ACTIONS.build_highway = function(a)
	CC.need(a, { town_ids = "ints" })
	if #a.town_ids ~= 2 then return { ok = false, error = "per ora una superstrada collega esattamente 2 citta'" } end
	local tmpl = highwayTemplate()
	if not tmpl then return { ok = false, error = "tipo di strada per superstrade non trovato (vedi sonda s5)" } end
	local c1, c2 = CC.posOf(a.town_ids[1]), CC.posOf(a.town_ids[2])
	local e1, e2 = townRoadEnd(a.town_ids[1], c2), townRoadEnd(a.town_ids[2], c1)
	if not e1 or not e2 then return { ok = false, error = "nessuna strada di uscita adatta ai margini delle citta'" } end
	local saved = { CC.trackTemplate, CC.MIN_CROSS_ANGLE, CC.CURVE_SEG_TYPE, CC.CURVE_ROAD_TYPE }
	CC.trackTemplate = function() return tmpl end
	CC.MIN_CROSS_ANGLE = 91
	CC.CURVE_SEG_TYPE = 0
	CC.CURVE_ROAD_TYPE = api.type.enum.RoadType.STREET
	local log = {}
	local ok, info
	for _, kf in ipairs({ 0.9, 0.5, 1.4 }) do
		-- in pcall: anche se qualcosa va storto le impostazioni del binario vengono ripristinate qui sotto
		local okP, r1, r2 = pcall(CC.buildCurvedTrack, e1, e2, 80, false, kf)
		if okP then ok, info = r1, r2 else ok, info = false, { error = tostring(r1) } end
		if ok or not info.retry then break end
		log[#log + 1] = tostring(info.error) .. ", provo un altro tracciato"
	end
	CC.trackTemplate, CC.MIN_CROSS_ANGLE, CC.CURVE_SEG_TYPE, CC.CURVE_ROAD_TYPE = saved[1], saved[2], saved[3], saved[4]
	if not ok then return { ok = false, error = tostring(info.error), log = log } end
	return { ok = true, template = tmpl, length = info.length, bridges = info.bridges, tunnels = info.tunnels,
		overpasses = info.overpasses, underpasses = info.underpasses, log = log }
end
-- ===================================================================== fine b4
-- ===================================================================== BOZZA (NON TESTATO) - b5 stazioni e depositi
-- Dimensionamento delle stazioni ferroviarie (lunghezza in base ai treni, numero di binari in base a linee e treni,
-- binari di transito), stazioni con N binari, scelta del posto con ripieghi in caso di conflitto di spazio,
-- treni mai piu' lunghi del marciapiede, comando diretto "costruisci deposito".
-- DA VERIFICARE in gioco (sonde s10 e prova p17): lunghezza dei modelli, parametro "length" della stazione,
-- posizione dei moduli per lunghezze diverse da 160 m, stazioni con piu' di 2 binari.

CC.STATION_SEG_LEN = CC.STATION_SEG_LEN or 40       -- un pezzo di marciapiede = 40 m (4 pezzi = 160 m, verificato)
CC.DEFAULT_CAR_LEN = CC.DEFAULT_CAR_LEN or 26       -- ripiego se la lunghezza del modello non si legge
CC.DEFAULT_LOCO_LEN = CC.DEFAULT_LOCO_LEN or 22

-- ---------------------------------------------------------------- lunghezze dei treni
-- Lunghezza di un modello di veicolo (m) dal suo ingombro. DA VERIFICARE con la sonda s10: campo e asse.
function CC.modelLength(id)
	local L
	pcall(function()
		local bi = api.res.modelRep.get(id).boundingInfo
		local lx = bi.bbMax.x - bi.bbMin.x
		local ly = bi.bbMax.y - bi.bbMin.y
		L = math.max(lx, ly)                          -- il veicolo e' piu' lungo che largo: prendo il lato maggiore
	end)
	if not L or L <= 1 or L > 200 then return nil end
	return L
end

function CC.compositionLength(models)
	local tot = 0
	for i, id in ipairs(models) do
		tot = tot + (CC.modelLength(id) or (i == 1 and CC.DEFAULT_LOCO_LEN or CC.DEFAULT_CAR_LEN))
	end
	return tot
end

-- Lunghezza stimata di un treno passeggeri con nCars carrozze (modelli piu' recenti disponibili).
function CC.estimateTrainLength(nCars)
	local loco, car
	pcall(function() loco = CC.pickLocomotive(CC.railEra().catenary) end)
	pcall(function() car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true }) end)
	local L = (loco and CC.modelLength(loco.id)) or CC.DEFAULT_LOCO_LEN
	local c = (car and CC.modelLength(car.id)) or CC.DEFAULT_CAR_LEN
	return math.floor(L + c * (nCars or 3) + 0.5)
end

-- Quanti carri/carrozze entrano in un marciapiede lungo maxLen (almeno 1).
function CC.fitCars(locoId, carId, nCars, maxLen)
	if not maxLen then return nCars end
	local L = (locoId and CC.modelLength(locoId)) or CC.DEFAULT_LOCO_LEN
	local c = (carId and CC.modelLength(carId)) or CC.DEFAULT_CAR_LEN
	local fit = math.floor((maxLen - L) / c)
	return math.max(1, math.min(nCars, fit))
end

-- ---------------------------------------------------------------- piano di una stazione
-- p = { kind = "passengers" | "cargo", lines = linee che fermano, trains = treni che fermano (totale),
--       train_len = metri del treno piu' lungo, double = linea a doppio binario, through = linee che passano
--       senza fermarsi (> 0: binari di transito), terminal = capolinea, cargo_types = merci diverse (scali),
--       max_tracks = limite (default 8) }
-- Ritorna { segments, length, tracks, through, layout, notes }.
-- Regole (vedi dev-notes/note/TODO.md, "Dimensionamento delle stazioni"):
--   - lunghezza: il treno piu' lungo + 10 m di margine, a pezzi da 40 m (minimo 2 pezzi = 80 m);
--   - binario unico (1) se ferma un solo treno di una sola linea; 2 se i treni devono incrociarsi;
--     doppio binario: almeno un binario per senso; una linea in piu' = binari in piu';
--   - capolinea con 3 o piu' treni: un binario in piu' (i treni restano fermi di piu');
--   - scali merci: un binario per merce, uno in piu' se i treni sono di piu' (uno carica, l'altro arriva);
--   - binari di transito: 1 (2 con doppio binario) se ci sono linee che non fermano.
function CC.planStation(p)
	p = p or {}
	local seg = CC.STATION_SEG_LEN
	local trainLen = p.train_len or 120
	local segments = math.max(2, math.min(12, math.ceil((trainLen + 10) / seg)))
	local trains = math.max(1, p.trains or 1)
	local lines = math.max(1, p.lines or 1)
	local tracks, notes = 1, {}
	if p.kind == "cargo" then
		-- VERIFICATO solo lo scalo a 1 binario da 160 m (copiato da uno fatto a mano): i treni merci restano entro 150 m
		-- e gli altri treni aspettano fuori stazione (binario d'attesa). Merci diverse: vagoni misti sullo stesso binario.
		tracks = 1
		segments = 4
		if trains > 1 then notes[#notes + 1] = "scalo a 1 binario: gli altri treni aspettano fuori stazione (serve un binario d'attesa)" end
		if (p.cargo_types or 1) > 1 then notes[#notes + 1] = "merci diverse sullo stesso binario (scalo universale)" end
		if trainLen > 150 then notes[#notes + 1] = "treno accorciato a 150 m (scalo da 160 m)" end
	elseif p.double then
		tracks = math.max(2, 2 * math.ceil(lines / 2))
		if trains > 2 * tracks then tracks = tracks + 2 end
	else
		if trains <= 1 and lines <= 1 then
			tracks = 1
			notes[#notes + 1] = "binario unico: un solo treno, nessun incrocio"
		else
			tracks = 2
		end
		if lines >= 2 then tracks = math.max(tracks, lines) end
	end
	if p.terminal and p.kind ~= "cargo" and trains >= 3 then tracks = tracks + 1 end
	local through = 0
	if (p.through or 0) > 0 then through = p.double and 2 or 1 end
	local maxT = p.max_tracks or 8
	if tracks + through > maxT then
		notes[#notes + 1] = "binari ridotti al massimo di " .. maxT
		through = math.max(0, math.min(through, maxT - tracks))
		tracks = math.min(tracks, maxT - through)
	end
	return { segments = segments, length = segments * seg, tracks = tracks, through = through,
		layout = CC.stationLayout(tracks, through), kind = p.kind or "passengers", notes = notes }
end

-- Disposizione delle colonne della stazione: "P" marciapiede, "T" binario. Ogni binario ha un marciapiede accanto
-- (marciapiedi a isola tra due binari): 1 -> "PT" (come la stazione copiata nel gioco), 2 -> "PTTP",
-- 3 -> "PTTPTP", 4 -> "PTTPTTP". I binari di transito sono binari in piu': un treno che non ferma passa su un
-- binario libero qualsiasi (le fermate le decide la linea, non il binario).
function CC.stationLayout(tracks, through)
	local k = math.max(1, tracks or 1) + math.max(0, through or 0)
	if k == 1 then return "PT" end
	local s = "P"
	for i = 1, k do
		s = s .. "T"
		if i % 2 == 0 then s = s .. "P" end
	end
	if k % 2 == 1 then s = s .. "P" end
	return s
end

-- Posizioni (in unita' del gioco, 10 = un pezzo da 40 m) dei pezzi lungo la stazione.
-- Verificato solo per 4 pezzi: -10, 0, 10, 20. Per n pezzi si estende allo stesso modo. DA VERIFICARE (s10).
function CC.moduleOffsets(segments)
	local start = -10 * math.floor((segments - 1) / 2)
	local out = {}
	for k = 1, segments do out[k] = start + 10 * (k - 1) end
	return out
end

-- Parametro "length" della stazione modulare. Verificato solo 3 -> 160 m (4 pezzi). DA VERIFICARE (s10).
function CC.stationLengthParam(segments)
	if CC.STATION_LENGTH_PARAMS and CC.STATION_LENGTH_PARAMS[segments] then return CC.STATION_LENGTH_PARAMS[segments] end
	return math.max(0, segments - 1)
end

-- Modulo marciapiede merci (dal modello copiato con la sonda s6 o cercato tra i moduli).
function CC.cargoPlatformModule(e)
	e = e or CC.railEra()
	if CC.CARGO_PLATFORM_MODULE then return CC.CARGO_PLATFORM_MODULE end
	local all = {}
	pcall(function() for _, n in ipairs(CC.each(api.res.moduleRep.getAll())) do all[tostring(n)] = true end end)
	local M = "::/stations/rail/modular_station/"
	for _, cand in ipairs({ M .. "platform_cargo_era_" .. e.era .. ".module", M .. "platform_cargo.module", M .. "cargo_platform_era_" .. e.era .. ".module" }) do
		if all[cand] then return cand end
	end
	for n in pairs(all) do
		if n:find("modular_station", 1, true) and n:find("cargo", 1, true) and n:find("platform", 1, true) then return n end
	end
	return nil
end

-- Moduli della stazione per una disposizione qualsiasi (stesso schema degli slot della stazione da 160 m copiata
-- nel gioco: 84xxxxx binari, 74xxxxx marciapiedi, 104xxxxx tettoie, 340xxxx edifici, 108xxxxx scale).
function CC.railStationModulesN(e, layout, segments, kind)
	e = e or CC.railEra()
	local M = "::/stations/rail/modular_station/"
	local tr = CC.trackOverride or e.track
	local T = "::/trainstation___/infrastructure/track/" .. tr .. "/" .. tr .. (e.catenary and "_catenary" or "") .. ".street_template"
	local era = "_era_" .. e.era
	local cargo = kind == "cargo"
	-- VERIFICATO (4 crash del 07.10.2026): il marciapiede merci e' largo DUE colonne e usa gli slot 64xxxxx (non 74xxxxx).
	-- Messo come un marciapiede passeggeri (74xxxxx, binario nella colonna accanto) si sovrappone al binario e genera
	-- tratti doppi sotto i marciapiedi ("Duplicate edges found", quota -6 m): il gioco va in crash.
	-- Schema copiato da 3 scali costruiti a mano (sonda s22): 1 binario, 160 m (length = 3), specialization = 1:
	--   3701980 main_building_1_cargo, 64000xx marciapiede merci (colonna 0), 84020xx binario (colonna 2), xx = -10..20.
	-- Solo questo schema e' verificato: altre lunghezze o piu' binari vanno prima copiati da uno scalo fatto a mano.
	if cargo then
		if layout ~= "PT" or segments ~= 4 then
			return nil, "scalo merci: verificato solo con 1 binario e 160 m (chiesti " .. CC.layoutTracks(layout) .. " binari, " .. (segments * CC.STATION_SEG_LEN) .. " m)"
		end
		local platC = CC.cargoPlatformModule(e)
		if not platC then return nil, "modulo marciapiede merci non trovato" end
		local mods = { [3701980] = { name = M .. "main_building_1_cargo.module", variant = 0 } }
		for _, o in ipairs(CC.moduleOffsets(4)) do
			mods[6400000 + o] = { name = platC, variant = 0 }
			mods[8402000 + o] = { name = T, variant = 0 }
		end
		return mods, nil, { specialization = 1 }
	end
	local plat = M .. "platform_passenger" .. era .. ".module"
	local mods = {}
	do
		mods[3400020] = M .. "main_building_1" .. era .. ".module"
		if segments >= 4 then
			mods[3400005] = M .. "side_building_1" .. era .. ".module"
			mods[3400035] = M .. "side_building_1" .. era .. ".module"
		end
		mods[10800000] = M .. "addon_platform_passenger_stairs" .. era .. ".module"
	end
	for _, o in ipairs(CC.moduleOffsets(segments)) do
		for c = 0, #layout - 1 do
			local ch = layout:sub(c + 1, c + 1)
			if ch == "T" then
				mods[8400000 + c * 1000 + o] = T
			else
				mods[7400000 + c * 1000 + o] = plat
				mods[10400000 + c * 1000 + o] = M .. "platform_passenger_roof" .. era .. ".module"
			end
		end
	end
	local out = {}
	for k, v in pairs(mods) do out[k] = { name = v, variant = 0 } end
	return out
end

function CC.layoutTracks(layout)
	local n = 0
	for _ in layout:gmatch("T") do n = n + 1 end
	return n
end

-- Estremo libero di un binario: nodo, posizione e direzione verso l'esterno (nil se il nodo non e' un estremo).
function CC.trackEndInfo(node)
	local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(node))
	if #segs ~= 1 then return nil end
	local be = CC.comp(segs[1], api.type.ComponentType.BASE_EDGE)
	if not be then return nil end
	local first = be.node0 == node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local tx, ty = t.x, t.y
	if first then tx, ty = -tx, -ty end
	local tl = math.sqrt(tx * tx + ty * ty)
	if tl < 1e-6 then return nil end
	return { node = node, x = p.x, y = p.y, z = p.z, dx = tx / tl, dy = ty / tl, edge = segs[1] }
end

-- Unisce gli estremi (paralleli, stessa direzione) in uno solo con una serie di scambi ("scala").
-- ends ordinati di lato; il primo prosegue dritto, gli altri lo raggiungono uno alla volta (CC.buildThroat).
function CC.mergeEnds(ends, L)
	if #ends == 1 then return true, { endInfo = ends[1], edges = {} } end
	local cur, edges = ends[1], {}
	for i = 2, #ends do
		local okT, T = CC.buildThroat(cur, ends[i], L)
		if not okT then return false, { error = tostring(T.error), edges = edges } end
		for _, e in ipairs(T.edges) do edges[#edges + 1] = e end
		cur = T.endInfo
	end
	return true, { endInfo = cur, edges = edges }
end

-- Stazione ferroviaria con disposizione qualsiasi.
-- opts = { layout = "PTTP", segments = 4, kind = "passengers" | "cargo", name, merge = { f = true, b = true } }
-- merge.f / merge.b: unire i binari in un solo estremo verso +d (f) o verso -d (b). Senza unione restano tutti gli
-- estremi di quel lato (servono per il doppio binario o per un deposito accanto alla linea).
-- Ritorna ok, { construction, station, group, ends, sides = { f = {...}, b = {...} }, edges, tracks, length }
function CC.buildRailStationN(cx, cy, dx, dy, opts)
	opts = opts or {}
	local CT = api.type.ComponentType
	local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	local layout = opts.layout or "PTTP"
	local segments = opts.segments or 4
	local nT = CC.layoutTracks(layout)
	local merge = opts.merge or { f = true, b = true }
	local mods, merr, extra = CC.railStationModulesN(nil, layout, segments, opts.kind)
	if not mods then return false, { error = merr } end
	local z = opts.z or CC.heightAt(cx, cy) or 0
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = "::/stations/rail/modular_station/modular_station.con"
	ce.params = { year = CC.year(), seed = 0, modules = mods, tracks = nT, length = CC.stationLengthParam(segments) }
	for k, v in pairs(extra or {}) do ce.params[k] = v end
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(cx, cy, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = opts.name or "Stazione"
	prop.constructionsToAdd = { ce }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "stazione rifiutata" } end
	local con
	for _, e in ipairs(ents or {}) do
		local c = CC.comp(e, CT.CONSTRUCTION)
		if c and #CC.each(c.stations) > 0 then con = e end
	end
	if not con then return false, { error = "stazione non trovata dopo la costruzione" } end
	local c = CC.comp(con, CT.CONSTRUCTION)
	local st = CC.each(c.stations)[1]
	local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
	if opts.name and okG then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(g, opts.name)) end) end
	local raw = CC.railStationEnds(con)
	if #raw ~= 2 * nT then
		return false, { error = "la stazione ha " .. #raw .. " estremi invece di " .. (2 * nT), construction = con }
	end
	local nx, ny = -dy, dx
	local sides = { f = {}, b = {} }
	for _, en in ipairs(raw) do
		local key = (en.dx * dx + en.dy * dy) > 0 and "f" or "b"
		table.insert(sides[key], en)
	end
	local edges, ends = {}, {}
	local thLen = CC.THROAT_LEN or ((CC.trackOverride or CC.railEra().track) == "simple" and 80 or 160)
	for _, key in ipairs({ "f", "b" }) do
		local list = sides[key]
		if #list ~= nT then
			CC.removeConstruction(con)
			return false, { error = "estremi della stazione non riconosciuti (" .. key .. ": " .. #list .. ")" }
		end
		table.sort(list, function(p, q) return (p.x * nx + p.y * ny) < (q.x * nx + q.y * ny) end)
		if merge[key] and nT > 1 then
			local okM, Mi = CC.mergeEnds(list, thLen)
			for _, e in ipairs(Mi.edges or {}) do edges[#edges + 1] = e end
			if not okM then
				CC.safeRemove(con, edges)
				return false, { error = "scambi della stazione rifiutati: " .. tostring(Mi.error) }
			end
			sides[key] = { Mi.endInfo }
		end
		for _, en in ipairs(sides[key]) do ends[#ends + 1] = en end
	end
	return true, { construction = con, station = st, group = okG and g or nil, ends = ends, sides = sides, edges = edges,
		tracks = nT, layout = layout, length = segments * CC.STATION_SEG_LEN }
end

function CC.expectedEnds(plan, merge)
	merge = merge or { f = true, b = true }
	local nT = CC.layoutTracks(plan.layout)
	local n = 0
	for _, k in ipairs({ "f", "b" }) do n = n + ((merge[k] or nT == 1) and 1 or nT) end
	return n
end

-- Stazione ferroviaria del giocatore entro r metri (per riusarla invece di costruirne un'altra accanto).
function CC.playerRailStationNear(x, y, r)
	local best, bd
	for g in pairs(CC.playerGroups()) do
		local p = CC.posOf(g)
		if p then
			local d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
			if d < r and (not bd or d < bd) then
				local rail = false
				pcall(function()
					local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
					for _, cr in ipairs(CC.each(car[1])) do if cr == api.type.enum.Carrier.RAIL then rail = true end end
				end)
				if rail then best, bd = g, d end
			end
		end
	end
	return best, bd
end

-- ---------------------------------------------------------------- posto della stazione con ripieghi
-- Prova in ordine (dal meno al piu' invasivo, vedi TODO "Conflitti di spazio"):
--   1. il piano completo, nei posti vicini e con orientamenti diversi (CC.placeRailStation);
--   2. posti piu' lontani dal centro (serve poi la navetta);
--   3. stazione piu' corta (treni piu' corti);
--   4. meno binari (gli incroci/sorpassi si fanno fuori stazione);
--   5. riuso di una stazione del giocatore vicina.
-- Non demolisce mai edifici: se nulla va, ritorna le alternative da proporre all'utente.
-- opts: score, accept, merge, min_segments, min_tracks, Rs. Ritorna info (o nil), { plan, steps, needs_feeder, shorter, ... }
function CC.placeStationSmart(center, dx, dy, nbs, name, plan, opts)
	opts = opts or {}
	local steps, budget = {}, opts.budget or 30
	local function copyPlan(p, changes)
		local q = {}
		for k, v in pairs(p) do q[k] = v end
		for k, v in pairs(changes or {}) do q[k] = v end
		q.layout = CC.stationLayout(q.tracks, q.through)
		q.length = q.segments * CC.STATION_SEG_LEN
		return q
	end
	local function attempt(label, p, Rs, tries)
		if budget <= 0 then steps[#steps + 1] = { step = label, ok = false, reasons = { "troppi tentativi" } }; return nil end
		local n = math.min(tries or 6, budget)
		budget = budget - n
		local st, why = CC.placeRailStation(center, dx, dy, nbs, name, {
			score = opts.score, accept = opts.accept, Rs = Rs or opts.Rs, maxTries = n,
			expectEnds = CC.expectedEnds(p, opts.merge),
			builder = function(x, y, ddx, ddy)
				return CC.buildRailStationN(x, y, ddx, ddy, { layout = p.layout, segments = p.segments, kind = p.kind, name = name, merge = opts.merge })
			end,
		})
		steps[#steps + 1] = { step = label, ok = st ~= nil, reasons = why }
		return st
	end
	local st = attempt("piano completo (" .. plan.tracks .. " binari, " .. plan.length .. " m)", plan, nil, 8)
	if st then return st, { plan = plan, steps = steps } end
	st = attempt("posti piu' lontani dal centro", plan, { 1000, 1300, 1600 }, 6)
	if st then return st, { plan = plan, steps = steps, needs_feeder = true } end
	for s = plan.segments - 1, math.max(2, opts.min_segments or 2), -1 do
		local p2 = copyPlan(plan, { segments = s })
		st = attempt("stazione piu' corta (" .. p2.length .. " m)", p2, nil, 4)
		if st then return st, { plan = p2, steps = steps, shorter = true, max_train_len = p2.length - 10 } end
	end
	for t = plan.tracks - 1, math.max(1, opts.min_tracks or 1), -1 do
		local p2 = copyPlan(plan, { tracks = t, through = 0 })
		st = attempt("meno binari (" .. t .. ")", p2, nil, 4)
		if st then return st, { plan = p2, steps = steps, fewer_tracks = true, note = "incroci e sorpassi vanno fatti fuori stazione" } end
	end
	local g = CC.playerRailStationNear(center.x, center.y, 900)
	if g then return nil, { steps = steps, reuse_group = g, message = "c'e' gia' una stazione del giocatore vicina: conviene usarla" } end
	return nil, { steps = steps, alternatives = {
		"stazione fuori citta' con navetta bus o tram verso il centro",
		"treni piu' corti con stazione piu' corta",
		"demolire alcuni edifici (solo se l'utente lo conferma)",
		"percorso diverso o citta' diversa",
	} }
end

-- ---------------------------------------------------------------- treni della giusta lunghezza
-- Fermata da cui far partire il k-esimo di n veicoli su una linea con nStops fermate (distribuiti lungo la linea).
function CC.staggerStop(k, n, nStops)
	if not nStops or nStops <= 1 or n <= 1 then return 0 end
	return math.floor((k - 1) * nStops / n) % nStops
end

-- Treno passeggeri (locomotiva + carrozze) mai piu' lungo di maxLen, assegnato alla linea dalla fermata stopIndex.
function CC.buyPassengerTrain(depot, line, nCars, stopIndex, maxLen, loco)
	loco = loco or CC.pickLocomotive(CC.railEra().catenary)
	local car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true })
	if not loco or not car then return false, { error = "nessun treno/carrozza disponibile" } end
	local n = CC.fitCars(loco.id, car.id, nCars or 3, maxLen)
	local models = { loco.id }
	for _ = 1, n do models[#models + 1] = car.id end
	local ok, veh, warn = CC.buyComposition(depot, models, line, stopIndex or 0)
	if not ok then return false, { error = tostring(veh) } end
	return true, { vehicle = veh, cars = n, warning = warn }
end

-- ---------------------------------------------------------------- depositi
-- Estremi liberi di binario (fuori dalle costruzioni e delle stazioni) entro r metri.
function CC.freeTrackEndsNear(x, y, r)
	local CT = api.type.ComponentType
	local out, seen = {}, {}
	pcall(function()
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE))) do
			local be = CC.comp(e, CT.BASE_EDGE)
			if be and tostring(be.roadTemplate):find("/track/", 1, true) then
				for _, n in ipairs({ be.node0, be.node1 }) do
					if not seen[n] then
						seen[n] = true
						local info = CC.trackEndInfo(n)
						if info then info.d = math.sqrt((info.x - x) ^ 2 + (info.y - y) ^ 2); out[#out + 1] = info end
					end
				end
			end
		end
	end)
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- Punto spostato "fuori dal centro": da p, lontano dal centro della citta' di d metri.
local function awayFromCenter(p, town, d)
	local c = town and CC.posOf(town)
	if not c then return p.x, p.y end
	local vx, vy = p.x - c.x, p.y - c.y
	local l = math.sqrt(vx * vx + vy * vy)
	if l < 1 then return p.x, p.y end
	return p.x + vx / l * d, p.y + vy / l * d
end

-- Costruisci deposito: kind = road | tram | rail | water. Vicino a una stazione (station_id) o a una citta' (town_id).
-- Strada/tram: capolinea di strada vicino, spostato verso l'esterno della citta'; deve raggiungere la stazione.
-- Ferrovia: su un estremo libero di binario vicino alla stazione (il piu' lontano dal centro).
-- Acqua: con lo schema copiato in gioco (CC.TEMPLATES.water_depot, sonda s6). Aerei/elicotteri: DA VERIFICARE se
-- serve un deposito (l'aeroporto potrebbe fare da hangar).
SIM_ACTIONS.build_depot = function(a)
	CC.need(a, { kind = "str", station_id = "id?", town_id = "id?", name = "str?" })
	local TM = api.type.enum.TransportMode
	local kind = a.kind
	local p = (a.station_id and CC.posOf(a.station_id)) or (a.town_id and CC.posOf(a.town_id))
	if not p then return { ok = false, error = "indica station_id o town_id" } end
	local town = a.town_id
	if not town and a.station_id then
		pcall(function() town = api.engine.system.stationSystem.getTown(CC.groupStation(a.station_id)) end)
		if town and town < 0 then town = nil end
	end
	local name = a.name or ("Deposito " .. (CC.nameOf(town or a.station_id) or ""))
	if kind == "road" or kind == "tram" then
		local x, y = awayFromCenter(p, town, 150)
		local ok, info = CC.buildDepotNear(x, y, kind, name, 900)
		if not ok then return { ok = false, error = tostring(info.error) } end
		local modes = kind == "tram" and { TM.TRAM, TM.ELECTRIC_TRAM } or { TM.BUS, TM.TRUCK }
		local reach = true
		if a.station_id then
			reach = false
			for _, n in ipairs(CC.groupNodes(a.station_id)) do
				if CC.hasPath(CC.depotNodes(info.depot), n, modes) then reach = true; break end
			end
		end
		return { ok = reach, depot_id = info.depot, error = (not reach) and "deposito costruito ma non raggiunge la stazione" or nil }
	elseif kind == "rail" then
		local cands = CC.freeTrackEndsNear(p.x, p.y, 500)
		local c = town and CC.posOf(town)
		if c then
			for _, e in ipairs(cands) do e.score = math.sqrt((e.x - c.x) ^ 2 + (e.y - c.y) ^ 2) - e.d * 0.5 end
			table.sort(cands, function(u, v) return u.score > v.score end)
		end
		local errs = {}
		for i = 1, math.min(4, #cands) do
			local okD, D = CC.depotAtEndSafe(cands[i], name, nil, {})
			if okD then return { ok = true, depot_id = D.depot } end
			errs[#errs + 1] = CC.errText(D)
			if D.construction then CC.removeConstruction(D.construction) end
		end
		-- nessun estremo libero o tutti rifiutati: deposito su una diramazione corta
		local blog = {}
		local okB, B = CC.railDepotByBranch(p, name, nil, blog)
		if okB then return { ok = true, depot_id = B.depot, log = blog } end
		return { ok = false, error = (#cands == 0 and "nessun estremo di binario libero" or table.concat(errs, "; ")) .. "; " .. table.concat(blog, "; ") }
	elseif kind == "water" then
		if not (CC.TEMPLATES and CC.TEMPLATES.water_depot) then
			return { ok = false, error = "schema del deposito navale non ancora copiato (sonda s6 su un deposito fatto a mano)" }
		end
		local okT, info = CC.buildTemplateNear("water_depot", town or a.station_id, name)
		return { ok = okT, depot = info, error = (not okT) and tostring(info) or nil }
	end
	return { ok = false, error = "tipo di deposito non gestito: " .. tostring(kind) .. " (aerei/elicotteri: da verificare se serve)" }
end
-- ===================================================================== fine b5
-- ===================================================================== BOZZA (NON TESTATO) - b6 binari
-- Doppio binario (un binario per senso con segnali a senso unico), diramazioni, binari d'incrocio/attesa,
-- segnali, linee circolari (anello) percorse nei due sensi.
-- DA VERIFICARE in gioco (sonda s8 e prove p12, p13): come si piazza un segnale da script (EdgeObject), il nome del
-- modello del segnale e quale lato/verso corrisponde al senso di marcia.

CC.TRACK_SPACING = CC.TRACK_SPACING or 5          -- distanza tra gli assi dei due binari (m)
CC.SPLIT_LEN = CC.SPLIT_LEN or 120                -- lunghezza della diramazione (scambio) che apre il doppio binario
CC.SIGNAL_EVERY = CC.SIGNAL_EVERY or 700          -- un segnale ogni ... m (blocchi: piu' treni sulla stessa tratta)
CC.LEFT_HAND_TRAFFIC = CC.LEFT_HAND_TRAFFIC or false                   -- circolazione a destra (come in Italia)

local function unit6(x, y) local l = math.sqrt(x * x + y * y); if l < 1e-6 then return 1, 0 end return x / l, y / l end

-- Nodo di binario piu' vicino a (x, y) entro 2 m (per ritrovare i nodi nuovi dopo una proposta).
function CC.nodeAt(x, y)
	local CT = api.type.ComponentType
	local node, bd
	pcall(function()
		for _, n in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), 2, CT.BASE_NODE))) do
			local p = CC.comp(n, CT.BASE_NODE).position
			local d = (p.x - x) ^ 2 + (p.y - y) ^ 2
			if not bd or d < bd then node, bd = n, d end
		end
	end)
	return node
end

-- Estremo della stazione rivolto verso (x, y).
function CC.endToward(st, x, y)
	local best, bv
	for _, e in ipairs(st.ends) do
		local v = (x - e.x) * e.dx + (y - e.y) * e.dy
		if not bv or v > bv then best, bv = e, v end
	end
	return best
end

-- Diramazione: dall'estremo libero E partono due binari, uno dritto e uno spostato di lato di `spacing` m
-- (side = 1 a sinistra della direzione d'uscita, -1 a destra). E diventa uno scambio. Ritorna i due estremi nuovi.
-- Prova piu' varianti (lato, lunghezza) se la prima e' rifiutata: VERIFICATO p35 (08.10.2026) "Costruzione non
-- consentita" sulla prima diramazione dell'anello vicino al centro di una citta'.
function CC.buildSplit(E, L, spacing, side)
	if L or side then return CC.buildSplitOnce(E, L, spacing, side) end
	local errs = {}
	for _, v in ipairs({ { CC.SPLIT_LEN, 1 }, { CC.SPLIT_LEN, -1 }, { CC.SPLIT_LEN * 1.7, 1 }, { CC.SPLIT_LEN * 1.7, -1 }, { CC.SPLIT_LEN * 0.6, 1 }, { CC.SPLIT_LEN * 0.6, -1 } }) do
		local ok, r = CC.buildSplitOnce(E, v[1], spacing, v[2])
		if ok then return ok, r end
		errs[#errs + 1] = string.format("%.0f m lato %d: %s", v[1], v[2], tostring(r.error))
	end
	return false, { error = table.concat(errs, " | ") }
end
function CC.buildSplitOnce(E, L, spacing, side)
	L, spacing, side = L or CC.SPLIT_LEN, spacing or CC.TRACK_SPACING, side or 1
	local dx, dy = E.dx, E.dy
	local nx, ny = -dy * side, dx * side
	local ax, ay = E.x + dx * L, E.y + dy * L
	local bx, by = ax + nx * spacing, ay + ny * spacing
	local z = E.z
	local P0 = api.type.Vec3f.new(E.x, E.y, E.z)
	local A, B = api.type.Vec3f.new(ax, ay, z), api.type.Vec3f.new(bx, by, z)
	local nA, nB = api.type.NodeAndEntity.new(), api.type.NodeAndEntity.new()
	nA.entity = -1; nA.comp.position = A
	nB.entity = -2; nB.comp.position = B
	local TA = api.type.Vec3f.new(dx * L, dy * L, 0)
	local distB = math.sqrt((bx - E.x) ^ 2 + (by - E.y) ^ 2)
	local TB = api.type.Vec3f.new(dx * distB, dy * distB, 0)
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = { nA, nB }
	prop.streetProposal.edgesToAdd = { trackSeg(-3, E.node, P0, TA, -1, A, TA), trackSeg(-4, E.node, P0, TB, -2, B, TB) }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = "diramazione: " .. tostring(cmd) } end
	local ok, _, ents = CC.send(cmd)
	if not ok then return false, { error = "diramazione rifiutata" } end
	local edges = {}
	for _, en in ipairs(ents or {}) do if CC.comp(en, api.type.ComponentType.BASE_EDGE) then edges[#edges + 1] = en end end
	local a = { node = CC.nodeAt(ax, ay), x = ax, y = ay, z = z, dx = dx, dy = dy }
	local b = { node = CC.nodeAt(bx, by), x = bx, y = by, z = z, dx = dx, dy = dy }
	if not a.node or not b.node then return false, { error = "nodi della diramazione non trovati", edges = edges } end
	return true, { a = a, b = b, edges = edges }
end

-- Binario dritto di `len` m che prolunga l'estremo libero E. Ritorna il nuovo estremo.
function CC.extendTrack(E, len)
	local ex, ey = E.x + E.dx * len, E.y + E.dy * len
	local P0, P1 = api.type.Vec3f.new(E.x, E.y, E.z), api.type.Vec3f.new(ex, ey, E.z)
	local T = api.type.Vec3f.new(E.dx * len, E.dy * len, 0)
	local n = api.type.NodeAndEntity.new()
	n.entity = -1; n.comp.position = P1
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = { n }
	prop.streetProposal.edgesToAdd = { trackSeg(-2, E.node, P0, T, -1, P1, T) }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = "prolungamento: " .. tostring(cmd) } end
	local ok, _, ents = CC.send(cmd)
	if not ok then return false, { error = "prolungamento rifiutato" } end
	local edges = {}
	for _, en in ipairs(ents or {}) do if CC.comp(en, api.type.ComponentType.BASE_EDGE) then edges[#edges + 1] = en end end
	local node = CC.nodeAt(ex, ey)
	if not node then return false, { error = "nodo nuovo non trovato", edges = edges } end
	return true, { endInfo = { node = node, x = ex, y = ey, z = E.z, dx = E.dx, dy = E.dy }, edges = edges }
end

-- Binario d'accesso da un estremo libero: avanti len m e di lato lat m (side 1 = sinistra), uscita parallela. Serve per
-- staccare un deposito dai binari vicini (VERIFICATO p24: il deposito messo subito sull'estremo urta il binario accanto).
function CC.leadTrack(E, len, lat, side)
	local dx, dy = E.dx, E.dy
	local nx, ny = -dy * (side or 1), dx * (side or 1)
	local ex, ey = E.x + dx * len + nx * lat, E.y + dy * len + ny * lat
	if not CC.inMap(ex, ey, 150) then return false, { error = "binario d'accesso fuori dai confini della mappa" } end
	local P0, P1 = api.type.Vec3f.new(E.x, E.y, E.z), api.type.Vec3f.new(ex, ey, E.z)
	local d = math.sqrt((ex - E.x) ^ 2 + (ey - E.y) ^ 2)
	local T = api.type.Vec3f.new(dx * d, dy * d, 0)
	local n = api.type.NodeAndEntity.new()
	n.entity = -1; n.comp.position = P1
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = { n }
	prop.streetProposal.edgesToAdd = { trackSeg(-2, E.node, P0, T, -1, P1, T) }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = "binario d'accesso: " .. tostring(cmd) } end
	local ok, _, ents = CC.send(cmd)
	if not ok then return false, { error = "binario d'accesso rifiutato" } end
	local edges = {}
	for _, en in ipairs(ents or {}) do if CC.comp(en, api.type.ComponentType.BASE_EDGE) then edges[#edges + 1] = en end end
	local node = CC.nodeAt(ex, ey)
	if not node then return false, { error = "nodo nuovo non trovato", edges = edges } end
	return true, { endInfo = { node = node, x = ex, y = ey, z = E.z, dx = dx, dy = dy }, edges = edges }
end

-- ---------------------------------------------------------------- segnali
-- VERIFICATO in gioco (08.10.2026, build 40420, prove p26-p34 e mod "Automatic Signal Spacing"):
--  * il segnale e' un oggetto del binario: il binario si TOGLIE e si RIMETTE uguale (SegmentAndEntity con
--    comp = BASE_EDGE copiato, playerOwned copiato) con comp.objects = oggetti di prima + { -400000000 - k, 2 };
--    l'oggetto va in streetProposal.edgeObjectsToAdd (edgeEntity = id negativo del binario nuovo);
--  * EdgeObject.model = COSTRUZIONE "::/infrastructure/signal/signal_path_c.con" (segnale di percorso, quello del
--    gioco base e della partita di terzi); con il .mdl o senza binario rifatto il gioco lancia "Unknown exception";
--  * NIENTE verifica a secco: makeProposalData lancia "Unknown exception" con gli oggetti dei binari (il comando
--    invece funziona, dal lato simulazione e dall'interfaccia);
--  * verso: left = false -> il segnale vale per i treni che vanno da node0 a node1 (edgePr[2] = true);
--    left = true -> da node1 a node0; oneWay = true -> segnale a senso unico (SIGNAL_LIST type 1), false -> type 0.
--  * NON leggere mai una proposta del giocatore conservata (DEV.lastProposal) dopo che e' stata applicata: crash.
CC.SIGNAL_CON = CC.SIGNAL_CON or "::/infrastructure/signal/signal_path_c.con"

function CC.signalModel()
	if CC.SIGNAL_MODEL then return CC.SIGNAL_MODEL end
	local id = -1
	pcall(function() id = api.res.constructionRep.find(CC.SIGNAL_CON) end)
	if id and id >= 0 then return CC.SIGNAL_CON end
	return nil
end

local function edgeEnds(e)
	local be = CC.comp(e, api.type.ComponentType.BASE_EDGE)
	if not be then return nil end
	return be.position0, be.position1
end

-- Comando senza verifica a secco (vedi sopra). Ritorna ok, entita' create.
local function sendStreetObjects(prop)
	local player = api.engine.util.getPlayer()
	local ctx = api.type.Context.new(); ctx.player = player
	local okC, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, ctx, false, true)
	if not okC then return false, "comando dei segnali: " .. tostring(cmd):sub(1, 120) end
	local ok, _, ents = CC.send(cmd)
	return ok, ents
end

-- Segnali su binari ESISTENTI. items = { { edge = id, param = 0..1, left = bool, oneWay = bool }, ... }
-- (un segnale per binario). Ritorna ok, { signals = n, edges = { vecchio -> nuovo } }.
local function placeSignalsBatch(items)
	local CT = api.type.ComponentType
	local model = CC.signalModel()
	if not model then return false, { error = "costruzione del segnale non trovata: " .. tostring(CC.SIGNAL_CON) } end
	local player = api.engine.util.getPlayer()
	local prop = api.type.SimpleProposal.new()
	local rem, adds, objs, pos = {}, {}, {}, {}
	for k, it in ipairs(items) do
		local be = CC.comp(it.edge, CT.BASE_EDGE)
		if be and not CC.inConstruction(it.edge) then
			local list = {}
			for _, o in ipairs(be.objects or {}) do list[#list + 1] = { o[1], o[2] } end
			local sg = api.type.SegmentAndEntity.new()
			sg.entity = -k; sg.type = 1; sg.comp = be
			local po = CC.comp(it.edge, CT.PLAYER_OWNED)
			if po then sg.playerOwned = po end
			-- id provvisorio dell'oggetto = -400000000 - (posizione 0-based in edgeObjectsToAdd) (VERIFICATO p39 09.10.2026:
			-- con -400000000 - k, k da 1, il comando da' "Unknown exception"; p34 usava -400000000 per il primo)
			list[#list + 1] = { -400000000 - #objs, api.type.enum.EdgeObjectType.SIGNAL }
			sg.comp.objects = list
			local o = api.type.SimpleStreetProposal.EdgeObject.new()
			o.edgeEntity = -k; o.param = it.param or 0.5; o.oneWay = it.oneWay == true; o.left = it.left == true
			o.model = model; o.playerEntity = player
			rem[#rem + 1] = it.edge; adds[#adds + 1] = sg; objs[#objs + 1] = o
			pos[#pos + 1] = { old = it.edge, x = (be.position0.x + be.position1.x) / 2, y = (be.position0.y + be.position1.y) / 2 }
		end
	end
	if #objs == 0 then return true, { signals = 0, edges = {} } end
	prop.streetProposal.edgesToRemove = rem
	prop.streetProposal.edgesToAdd = adds
	prop.streetProposal.edgeObjectsToAdd = objs
	local ok, ents = sendStreetObjects(prop)
	if not ok then return false, { error = type(ents) == "string" and ents or "segnali rifiutati" } end
	-- i binari rifatti hanno id nuovi: li ritrovo dal punto medio
	local map = {}
	for _, q in ipairs(pos) do
		pcall(function()
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(q.x, q.y), 1, CT.BASE_EDGE))) do
				map[q.old] = e
			end
		end)
	end
	return true, { signals = #objs, edges = map }
end

-- Un segnale per comando (VERIFICATO p14 09.10.2026: due binari nella stessa proposta -> "Unknown exception" nel
-- comando; il caso a un binario e' quello verificato in p34).
function CC.placeSignals(items)
	local total, map, errs = 0, {}, {}
	for _, it in ipairs(items or {}) do
		local ok, r = placeSignalsBatch({ it })
		if ok then
			total = total + (r.signals or 0)
			for k, v in pairs(r.edges or {}) do map[k] = v end
		else
			errs[#errs + 1] = tostring(r.error)
		end
	end
	if total == 0 and #errs > 0 then return false, { error = errs[1], edges = map } end
	return true, { signals = total, edges = map, warning = (#errs > 0) and (#errs .. " segnali non messi: " .. errs[1]) or nil }
end

-- I binari con un segnale nuovo cambiano id: aggiorna una lista (per l'annulla) con la mappa vecchio -> nuovo.
function CC.remapEdges(list, map)
	if not list or not map then return end
	for i, e in ipairs(list) do if map[e] then list[i] = map[e] end end
end

-- Segnali lungo una serie di binari (edges di un tracciato), ogni opts.every m.
-- opts.from = { x, y }: da dove partono i treni (senso di marcia); opts.oneWay: senso unico (doppio binario).
-- Il segnale guarda nel senso di marcia (left calcolato dal verso node0 -> node1 del binario).
function CC.addSignals(edges, opts)
	opts = opts or {}
	local every = opts.every or CC.SIGNAL_EVERY
	local from = opts.from or { x = 0, y = 0 }
	local list = {}
	for _, e in ipairs(edges or {}) do
		local p0, p1 = edgeEnds(e)
		if p0 and not CC.inConstruction(e) then
			local d0 = (p0.x - from.x) ^ 2 + (p0.y - from.y) ^ 2
			local d1 = (p1.x - from.x) ^ 2 + (p1.y - from.y) ^ 2
			local len = math.sqrt((p1.x - p0.x) ^ 2 + (p1.y - p0.y) ^ 2)
			list[#list + 1] = { e = e, forward = d0 <= d1, len = len, key = math.min(d0, d1) }
		end
	end
	table.sort(list, function(u, v) return u.key < v.key end)
	local items, acc = {}, every / 2
	for _, it in ipairs(list) do
		acc = acc + it.len
		if acc >= every and it.len >= 20 then
			acc = 0
			-- forward = i treni vanno da node0 a node1 -> left = false
			items[#items + 1] = { edge = it.e, param = 0.5, oneWay = opts.oneWay == true, left = not it.forward }
		end
	end
	if #items == 0 then return true, { signals = 0 } end
	return CC.placeSignals(items)
end

-- ---------------------------------------------------------------- collegamento di due estremi
-- Come in build_rail_line: forme di curva diverse, deviazione, ripiego dall'alta velocita' allo standard.
function CC.linkTwoEnds(ea, eb, log, label)
	local ok, info
	for _, kf in ipairs({ 0.9, 0.5, 1.4, 0.3 }) do
		ok, info = CC.buildCurvedTrack(ea, eb, 60, false, kf)
		if ok then break end
		local em = tostring(info.error) .. " " .. ((info.detail and info.detail.msg) and table.concat(info.detail.msg, "; ") or "")
		if info.at then em = em .. string.format(" a %.0f,%.0f", info.at[1], info.at[2]) end
		if info.detail and info.detail.coll then em = em .. " coll " .. table.concat(info.detail.coll, ",", 1, math.min(6, #info.detail.coll)) end
		if not info.retry and not em:find("Curvatura", 1, true) and not em:find("non consentita", 1, true) then break end
		log[#log + 1] = label .. ": " .. em .. " (kf " .. kf .. "), provo un altro tracciato"
	end
	if not ok and info.retry and not CC.SKIP_DETOUR then
		ok, info = railDetour(ea, eb, log, label)
	end
	if not ok and not CC.trackOverride and CC.railEra().track == "high_speed" and not tostring(info.error):find("acqua", 1, true) then
		CC.trackOverride = "standard"
		log[#log + 1] = label .. ": alta velocita' rifiutata, uso binario standard"
		ok, info = CC.buildCurvedTrack(ea, eb, 60, false)
	end
	if ok then
		log[#log + 1] = label .. ": " .. tostring(info.length) .. " m, " .. (info.bridges or 0) .. " su ponte, " .. (info.tunnels or 0) .. " in galleria"
	end
	return ok, info
end

-- Due coppie di estremi -> abbinamento senza incroci (per lato rispetto alla direzione a -> b).
local function pairByLane(As, Bs, ax, ay, bx, by)
	local dx, dy = unit6(bx - ax, by - ay)
	local nx, ny = -dy, dx
	local function key(e) return e.x * nx + e.y * ny end
	table.sort(As, function(u, v) return key(u) < key(v) end)
	table.sort(Bs, function(u, v) return key(u) < key(v) end)
	return As, Bs
end

-- ---------------------------------------------------------------- binario parallelo
-- Copia parallela (a `offset` m, positivo = a destra del verso di percorrenza da startNode) di una catena di binari,
-- con ponti e gallerie uguali: metodo della mod "Parallel Tracks" (TF3). Gli estremi si agganciano ai nodi snapStart /
-- snapEnd se dati (estremi liberi della stazione), altrimenti nodi nuovi. Ritorna ok, { edges }.
local function hermite6(p0, t0, p1, t1, t)
	local t2, t3 = t * t, t * t * t
	local a, b, c, d = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
	return { p0[1] * a + t0[1] * b + p1[1] * c + t1[1] * d, p0[2] * a + t0[2] * b + p1[2] * c + t1[2] * d, p0[3] * a + t0[3] * b + p1[3] * c + t1[3] * d }
end
-- Pezzi per spezzare la strada e in sv (0..1) nel nodo nodeId, da mettere in una proposta piu' grande (stesso
-- metodo di CC.splitStreet): { node, edges = { 2 SegmentAndEntity }, configs, x, y, z }
function CC.streetSplitParts(e, sv, nodeId, idA, idB)
	local CT = api.type.ComponentType
	local be = CC.comp(e, CT.BASE_EDGE)
	local st = CC.comp(e, CT.BASE_EDGE_STREET)
	if not be or not st then return nil end
	local P0, T0, P1, T1 = { be.position0.x, be.position0.y, be.position0.z }, { be.tangent0.x, be.tangent0.y, be.tangent0.z },
		{ be.position1.x, be.position1.y, be.position1.z }, { be.tangent1.x, be.tangent1.y, be.tangent1.z }
	local P = hermite6(P0, T0, P1, T1, sv)
	local s0, s1 = math.max(0, sv - 1e-3), math.min(1, sv + 1e-3)
	local Pa, Pb = hermite6(P0, T0, P1, T1, s0), hermite6(P0, T0, P1, T1, s1)
	local D = { (Pb[1] - Pa[1]) / (s1 - s0), (Pb[2] - Pa[2]) / (s1 - s0), (Pb[3] - Pa[3]) / (s1 - s0) }
	local nd = api.type.NodeAndEntity.new()
	nd.entity = nodeId
	nd.comp.position = api.type.Vec3f.new(P[1], P[2], P[3])
	local function V(a, k) return api.type.Vec3f.new(a[1] * k, a[2] * k, a[3] * k) end
	local function half(id, n0, q0, tt0, n1, q1, tt1)
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = id; sg.type = 0
		sg.comp = CC.comp(e, CT.BASE_EDGE)
		sg.comp.node0 = n0; sg.comp.node1 = n1
		sg.comp.position0 = q0; sg.comp.position1 = q1; sg.comp.tangent0 = tt0; sg.comp.tangent1 = tt1
		sg.comp.objects = {}
		sg.streetEdge = st
		local po = CC.comp(e, CT.PLAYER_OWNED)
		if po then sg.playerOwned = po end
		return sg
	end
	local Q = V(P, 1)
	local edges = {
		half(idA, be.node0, V(P0, 1), V(T0, sv), nodeId, Q, V(D, sv)),
		half(idB, nodeId, Q, V(D, 1 - sv), be.node1, V(P1, 1), V(T1, 1 - sv)),
	}
	local cfg = {}
	for _, nn in ipairs({ be.node0, be.node1 }) do if CC.comp(nn, CT.BASE_NODE_CONFIG) then cfg[#cfg + 1] = nn end end
	return { node = nd, edges = edges, configs = cfg, x = P[1], y = P[2], z = P[3] }
end
function CC.parallelTrack(edges, startNode, offset, snapStart, snapEnd, opts)
	local CT = api.type.ComponentType
	local function v(x) return { x.x, x.y, x.z } end
	local segs, byNode = {}, {}
	for _, e in ipairs(edges or {}) do
		local be = CC.comp(e, CT.BASE_EDGE)
		if be and tostring(be.roadTemplate):find("/track/", 1, true) then
			local sg = { edge = e, n0 = be.node0, n1 = be.node1, p0 = v(be.position0), t0 = v(be.tangent0), p1 = v(be.position1), t1 = v(be.tangent1), comp = be }
			segs[#segs + 1] = sg
			for _, n in ipairs({ sg.n0, sg.n1 }) do byNode[n] = byNode[n] or {}; table.insert(byNode[n], sg) end
		end
	end
	if #segs == 0 then return false, { error = "nessun binario da affiancare" } end
	-- catena ordinata da startNode
	local steps, nodes, used, node = {}, { startNode }, {}, startNode
	while true do
		local nxt
		for _, sg in ipairs(byNode[node] or {}) do if not used[sg] then nxt = sg break end end
		if not nxt then break end
		used[nxt] = true
		local fwd = nxt.n0 == node
		steps[#steps + 1] = { sg = nxt, fwd = fwd }
		node = fwd and nxt.n1 or nxt.n0
		nodes[#nodes + 1] = node
	end
	if #steps ~= #segs then return false, { error = "binari non in fila (" .. #steps .. " su " .. #segs .. ")" } end
	-- opts.skipStart / skipEnd: metri da lasciare senza parallelo all'inizio e alla fine (per raccordarsi ai binari
	-- della stazione con una curva a S, VERIFICATO p35: gli assi dei binari delle stazioni distano 10-15 m, non 5)
	if opts and ((opts.skipStart or 0) > 0 or (opts.skipEnd or 0) > 0) then
		local function slen(sg) return math.sqrt((sg.p1[1] - sg.p0[1]) ^ 2 + (sg.p1[2] - sg.p0[2]) ^ 2) end
		local a0, acc = 1, 0
		while a0 < #steps and acc < (opts.skipStart or 0) do acc = acc + slen(steps[a0].sg); a0 = a0 + 1 end
		local b0, acc2 = #steps, 0
		while b0 > a0 and acc2 < (opts.skipEnd or 0) do acc2 = acc2 + slen(steps[b0].sg); b0 = b0 - 1 end
		if b0 - a0 < 1 then return false, { error = "tratto troppo corto per il binario parallelo" } end
		local s2, n2 = {}, {}
		for i = a0, b0 do s2[#s2 + 1] = steps[i]; n2[#n2 + 1] = nodes[i] end
		n2[#n2 + 1] = nodes[b0 + 1]
		steps, nodes = s2, n2
		snapStart, snapEnd = nil, nil
	end
	local pos, dir = {}, {}
	for i, st in ipairs(steps) do
		local sg = st.sg
		local pA, pB, tA, tB = sg.p0, sg.p1, sg.t0, sg.t1
		if not st.fwd then pA, pB = sg.p1, sg.p0; tA = { -sg.t1[1], -sg.t1[2], -sg.t1[3] }; tB = { -sg.t0[1], -sg.t0[2], -sg.t0[3] } end
		pos[i] = pos[i] or pA; dir[i] = dir[i] or tA
		pos[i + 1] = pB; dir[i + 1] = tB
	end
	local nodesToAdd, newPos, newEnt, nextNode = {}, {}, {}, -1000
	local roadSplit, roadEdges, roadRemove, roadCfg, roadEdgeId = {}, {}, {}, {}, -5000
	for i = 1, #nodes do
		local d = dir[i]
		local l = math.sqrt(d[1] * d[1] + d[2] * d[2])
		local rx, ry = d[2] / l, -d[1] / l
		local p = { pos[i][1] + rx * offset, pos[i][2] + ry * offset, pos[i][3] }
		local snap = (i == 1 and snapStart) or (i == #nodes and snapEnd) or nil
		-- passaggio a livello del binario 1 su questo nodo: anche il binario 2 attraversa la strada a raso
		-- (VERIFICATO p35: senza, "Collisione" con la strada). Si spezza la strada nel punto giusto.
		local crossNode
		CC._parDiag = CC._parDiag or {}
		if not snap and i > 1 and i < #nodes then
			local rux, ruy = rx * offset, ry * offset
			local rl = math.sqrt(rux * rux + ruy * ruy)
			for _, rs in ipairs(CC.each(api.engine.system.streetSystem.getNodeSegments(nodes[i]))) do
				local rbe = CC.comp(rs, CT.BASE_EDGE)
				if rbe and not tostring(rbe.roadTemplate):find("/track/", 1, true) and not crossNode then
					local atStart = rbe.node0 == nodes[i]
					local a0 = atStart and rbe.position0 or rbe.position1
					local a1 = atStart and rbe.position1 or rbe.position0
					local ux, uy = a1.x - a0.x, a1.y - a0.y
					local len = math.sqrt(ux * ux + uy * uy)
					if len > 1 then
						ux, uy = ux / len, uy / len
						local c = (ux * rux + uy * ruy) / rl
						if c > 0.3 then
							local dd = rl / c
							if dd < len - 3 and not roadSplit[rs] then
								-- strada spezzata NELLA STESSA proposta del binario 2 (come fa il gioco col mouse): uno
								-- splitStreet separato prima viene rifiutato (VERIFICATO p35: "Costruzione non consentita")
								local sp = atStart and (dd / len) or (1 - dd / len)
								nextNode = nextNode - 1
								local parts = CC.streetSplitParts(rs, sp, nextNode, roadEdgeId - 1, roadEdgeId - 2)
								roadEdgeId = roadEdgeId - 2
								if parts then
									roadSplit[rs] = true
									nodesToAdd[#nodesToAdd + 1] = parts.node
									for _, re in ipairs(parts.edges) do roadEdges[#roadEdges + 1] = re end
									roadRemove[#roadRemove + 1] = rs
									for _, nc in ipairs(parts.configs) do roadCfg[#roadCfg + 1] = nc end
									crossNode = { nextNode, parts.x, parts.y, parts.z }
								end
								CC._parDiag[#CC._parDiag + 1] = string.format("strada %d nodo %d c=%.2f d=%.1f/%.1f -> %s", rs, nodes[i], c, dd, len, parts and "spezzata" or "no")
							else
								CC._parDiag[#CC._parDiag + 1] = string.format("strada %d nodo %d troppo corta (%.1f/%.1f)", rs, nodes[i], dd, len)
							end
						end
					end
				end
			end
		end
		if crossNode then
			newEnt[i] = crossNode[1]; newPos[i] = { crossNode[2], crossNode[3], crossNode[4] }
		elseif snap then
			local bn = CC.comp(snap, CT.BASE_NODE)
			newEnt[i] = snap; newPos[i] = { bn.position.x, bn.position.y, bn.position.z }
			if math.sqrt((newPos[i][1] - p[1]) ^ 2 + (newPos[i][2] - p[2]) ^ 2) > 1.5 then
				return false, { error = string.format("estremo %d del binario parallelo a %.1f m dal nodo da agganciare", i, math.sqrt((newPos[i][1] - p[1]) ^ 2 + (newPos[i][2] - p[2]) ^ 2)) }
			end
		else
			nextNode = nextNode - 1
			local nd = api.type.NodeAndEntity.new()
			nd.entity = nextNode
			nd.comp.position = api.type.Vec3f.new(p[1], p[2], p[3])
			nodesToAdd[#nodesToAdd + 1] = nd
			newEnt[i] = nextNode; newPos[i] = p
		end
	end
	local edgesToAdd, nextEdge = {}, 0
	for i, st in ipairs(steps) do
		local sg = st.sg
		local tA, tB = sg.t0, sg.t1
		if not st.fwd then tA = { -sg.t1[1], -sg.t1[2], -sg.t1[3] }; tB = { -sg.t0[1], -sg.t0[2], -sg.t0[3] } end
		local q0, q1 = newPos[i], newPos[i + 1]
		local oc = math.sqrt((pos[i + 1][1] - pos[i][1]) ^ 2 + (pos[i + 1][2] - pos[i][2]) ^ 2 + (pos[i + 1][3] - pos[i][3]) ^ 2)
		local nc = math.sqrt((q1[1] - q0[1]) ^ 2 + (q1[2] - q0[2]) ^ 2 + (q1[3] - q0[3]) ^ 2)
		local k = oc > 0.01 and nc / oc or 1
		local u0, u1 = { tA[1] * k, tA[2] * k, tA[3] * k }, { tB[1] * k, tB[2] * k, tB[3] * k }
		local n0, n1 = newEnt[i], newEnt[i + 1]
		if not st.fwd then n0, n1, q0, q1, u0, u1 = newEnt[i + 1], newEnt[i], q1, q0, { -u1[1], -u1[2], -u1[3] }, { -u0[1], -u0[2], -u0[3] } end
		nextEdge = nextEdge - 1
		local e = api.type.SegmentAndEntity.new()
		e.entity = nextEdge; e.type = 1
		e.comp.node0 = n0; e.comp.node1 = n1
		e.comp.position0 = api.type.Vec3f.new(q0[1], q0[2], q0[3]); e.comp.position1 = api.type.Vec3f.new(q1[1], q1[2], q1[3])
		e.comp.tangent0 = api.type.Vec3f.new(u0[1], u0[2], u0[3]); e.comp.tangent1 = api.type.Vec3f.new(u1[1], u1[2], u1[3])
		local src = sg.comp
		e.comp.type = src.type; e.comp.typeIndex = src.typeIndex
		e.comp.roadType = api.type.enum.RoadType.TRACK
		local name = src.roadTemplate
		local okT, tmpl = pcall(function() return api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(name)) end)
		pcall(function() e.comp.distance = (src.distance and src.distance > 0) and src.distance or CC.TRACK_SPACING end)
		if okT and tmpl then
			e.comp.laneConfigs = tmpl.laneConfigs; e.comp.roadTemplate = name; e.comp.roadStyle = tmpl.streetStyle
			pcall(function() if tmpl.trackDistance and tmpl.trackDistance > 0 then e.comp.distance = tmpl.trackDistance end end)
		else
			e.comp.laneConfigs = src.laneConfigs; e.comp.roadTemplate = src.roadTemplate; e.comp.roadStyle = src.roadStyle
		end
		local po = CC.comp(sg.edge, CT.PLAYER_OWNED)
		if po then e.playerOwned = po end
		edgesToAdd[#edgesToAdd + 1] = e
	end
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = nodesToAdd
	for _, re in ipairs(roadEdges) do edgesToAdd[#edgesToAdd + 1] = re end
	prop.streetProposal.edgesToAdd = edgesToAdd
	if #roadRemove > 0 then prop.streetProposal.edgesToRemove = roadRemove end
	if #roadCfg > 0 then prop.streetProposal.nodeConfigsToRemove = roadCfg end
	local player = api.engine.util.getPlayer()
	local ctx = api.type.Context.new()
	ctx.player = player
	pcall(function() ctx.extendProposalRedoPillars = true end)
	pcall(function() ctx.checkTerrainAlignment = true end)
	pcall(function() ctx.gatherFields = true end)
	local okC, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, ctx, false, true)
	if not okC then return false, { error = "binario parallelo: " .. tostring(cmd):sub(1, 120) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then
		local info = res and CC.proposalErrors(res) or {}
		local kinds, laneSet = {}, {}
		for _, sg in ipairs(segs) do laneSet[sg.edge] = true end
		for i, c in ipairs(info.coll or {}) do
			if i > 6 then break end
			local k = "altro"
			if laneSet[c] then k = "binario da affiancare"
			elseif c < 0 then k = "pezzo nuovo " .. c
			elseif CC.comp(c, CT.CONSTRUCTION) then k = "costruzione " .. tostring(CC.comp(c, CT.CONSTRUCTION).fileName):gsub("^.*/", "")
			elseif CC.comp(c, CT.BASE_EDGE) then
				local cb = CC.comp(c, CT.BASE_EDGE)
				k = "strada/binario " .. tostring(cb.roadTemplate):gsub("^.*/", "") .. string.format(" (%.0f,%.0f)-(%.0f,%.0f)", cb.position0.x, cb.position0.y, cb.position1.x, cb.position1.y)
			elseif CC.comp(c, CT.BASE_NODE) then k = "nodo" end
			kinds[#kinds + 1] = tostring(c) .. "=" .. k
		end
		local dg = table.concat(CC._parDiag or {}, "; "); CC._parDiag = {}
		return false, { error = "[" .. dg .. "] binario parallelo rifiutato" .. ((info.msg and #info.msg > 0) and (" (" .. table.concat(info.msg, "; ") .. ")") or "") .. (#kinds > 0 and (" con " .. table.concat(kinds, ", ")) or "") }
	end
	local out = {}
	for _, en in ipairs(ents or {}) do if CC.comp(en, CT.BASE_EDGE) then out[#out + 1] = en end end
	local first = newPos[1]; local last = newPos[#newPos]
	return true, { edges = out, startNode = CC.nodeAt(first[1], first[2]), endNode = CC.nodeAt(last[1], last[2]) }
end

-- Doppio binario tra due "gruppi" di estremi: As (2 estremi dalla parte a), Bs (2 dalla parte b).
-- Il binario a destra (rispetto al verso a -> b) e' per i treni a -> b, l'altro per b -> a (al contrario con
-- CC.LEFT_HAND_TRAFFIC). Segnali a senso unico su entrambi.
function CC.linkDouble(As, Bs, log, label, builtEdges)
	local ca = { x = (As[1].x + As[2].x) / 2, y = (As[1].y + As[2].y) / 2 }
	local cb = { x = (Bs[1].x + Bs[2].x) / 2, y = (Bs[1].y + Bs[2].y) / 2 }
	As, Bs = pairByLane(As, Bs, ca.x, ca.y, cb.x, cb.y)
	-- il lato si decide sulle direzioni vere degli estremi, non sulla corda a -> b: su un anello il binario arriva in b
	-- da tutt'altra parte (VERIFICATO p35: binario 2 a est del binario 1 ma estremo di b a ovest -> raccordo rifiutato)
	local swappedB = false
	if As[1].dx and Bs[1].dx then
		local sA = (As[2].x - As[1].x) * As[1].dy - (As[2].y - As[1].y) * As[1].dx
		local sB = -((Bs[2].x - Bs[1].x) * Bs[1].dy - (Bs[2].y - Bs[1].y) * Bs[1].dx)
		if sA * sB < 0 then Bs = { Bs[2], Bs[1] }; swappedB = true end
		local function f(e) return string.format("%d(%.0f,%.0f d%.2f,%.2f)", e.node or 0, e.x, e.y, e.dx, e.dy) end
		log[#log + 1] = label .. string.format(": estremi a %s %s, b %s %s, lati %.1f %.1f", f(As[1]), f(As[2]), f(Bs[1]), f(Bs[2]), sA, sB)
	end
	local warnings = {}
	-- binario 1 con il tracciato normale, binario 2 PARALLELO al primo (stessi ponti e gallerie); se il parallelo
	-- non si puo' fare, binario 2 con un tracciato suo (ripiego, avviso).
	local lane1
	local laneEdges = {}
	for k = 1, 2 do
		local ok, info
		if k == 2 and lane1 then
			local d = As[1]
			local off = (As[2].x - As[1].x) * d.dy - (As[2].y - As[1].y) * d.dx
			if math.abs(math.abs(off) - CC.TRACK_SPACING) < 0.5 then
				ok, info = CC.parallelTrack(lane1, As[1].node, off, As[2].node, Bs[2].node)
			else
				-- binari della stazione piu' lontani di 5 m: parallelo a 5 m che parte/finisce 150 m piu' in la',
				-- raccordato ai binari della stazione con curve a S
				local o5 = (off < 0 and -1 or 1) * CC.TRACK_SPACING
				ok, info = CC.parallelTrack(lane1, As[1].node, o5, nil, nil, { skipStart = CC.PARALLEL_JOIN or 150, skipEnd = CC.PARALLEL_JOIN or 150 })
				if ok then
					local edges2 = info.edges
					local EP0, EP1 = info.startNode and CC.trackEndInfo(info.startNode), info.endNode and CC.trackEndInfo(info.endNode)
					local okJ1, J1, okJ2, J2
					if EP0 then okJ1, J1 = CC.linkTwoEnds(As[2], EP0, log, label .. " (raccordo 2 in uscita)") end
					if okJ1 and EP1 then okJ2, J2 = CC.linkTwoEnds(EP1, Bs[2], log, label .. " (raccordo 2 in entrata)") end
					if okJ1 and okJ2 then
						for _, e in ipairs(J1.edges or {}) do edges2[#edges2 + 1] = e end
						for _, e in ipairs(J2.edges or {}) do edges2[#edges2 + 1] = e end
						info = { edges = edges2 }
					else
						for _, e in ipairs(edges2) do builtEdges[#builtEdges + 1] = e end
						for _, e in ipairs((J1 and J1.edges) or {}) do builtEdges[#builtEdges + 1] = e end
						ok, info = false, { error = "raccordi del binario parallelo non riusciti: " .. tostring((J1 and J1.error) or (J2 and J2.error) or "estremi non trovati") }
					end
				end
			end
			if ok then
				log[#log + 1] = label .. " (binario 2): parallelo al binario 1 a " .. string.format("%.1f", CC.TRACK_SPACING) .. " m"
			else
				warnings[#warnings + 1] = label .. ": binario 2 non parallelo (" .. tostring(info.error) .. "), tracciato separato"
				log[#log + 1] = label .. " (binario 2): parallelo non riuscito: " .. tostring(info.error) .. string.format(" (offset %.1f m)", off)
			end
		end
		if not ok then ok, info = CC.linkTwoEnds(As[k], Bs[k], log, label .. (k == 1 and " (binario 1)" or " (binario 2)")) end
		if not ok and k == 1 and swappedB then
			-- stesso abbinamento senza incroci, ma scambiando gli estremi di a invece di quelli di b
			log[#log + 1] = label .. " (binario 1): riprovo con gli estremi di a scambiati"
			As, Bs = { As[2], As[1] }, { Bs[2], Bs[1] }
			ok, info = CC.linkTwoEnds(As[1], Bs[1], log, label .. " (binario 1)")
		end
		if ok and k == 1 then lane1 = info.edges end
		if not ok then
			local msg = tostring(info.error)
			if info.detail and info.detail.msg then msg = msg .. " (" .. table.concat(info.detail.msg, "; ") .. ")" end
			return false, label .. ": " .. msg
		end
		for _, e in ipairs(info.edges or {}) do builtEdges[#builtEdges + 1] = e end
		laneEdges[k] = info.edges or {}
	end
	-- segnali DOPO aver costruito i due binari (rifare un binario per il segnale ne cambia l'id)
	for k = 1, 2 do
		-- k = 1: lato destro (chiave piu' bassa rispetto alla normale sinistra) -> treni da a verso b
		local aToB = (k == 1) ~= CC.LEFT_HAND_TRAFFIC
		local okS, S = CC.addSignals(laneEdges[k], { oneWay = true, from = aToB and ca or cb })
		if not okS then warnings[#warnings + 1] = label .. ": " .. tostring(S.error) end
		CC.remapEdges(builtEdges, okS and S.edges)
	end
	return true, { warnings = warnings }
end

-- Doppio binario tra stazioni consecutive: ogni stazione ha i binari uniti in uno scambio per lato (come oggi);
-- fuori da ogni scambio una diramazione apre i due binari, che arrivano alla diramazione della stazione dopo.
-- Nelle stazioni i treni dei due sensi si incrociano sui binari della stazione.
function CC.linkStationsDouble(stations, log, builtEdges, built, loco, opts)
	opts = opts or {}
	local used, warnings = {}, {}
	for i = 1, #stations - 1 do
		local sa, sb = stations[i], stations[i + 1]
		local pa, pb = CC.posOf(sb.group), CC.posOf(sa.group)
		local ea, eb = CC.endToward(sa, pa.x, pa.y), CC.endToward(sb, pb.x, pb.y)
		if used[ea.node] or used[eb.node] then return false, "orientamento delle stazioni non compatibile" end
		used[ea.node] = true; used[eb.node] = true
		local okA, SA = CC.buildSplit(ea)
		if not okA then return false, "doppio binario " .. i .. "-" .. (i + 1) .. ": " .. tostring(SA.error) end
		local okB, SB = CC.buildSplit(eb)
		if not okB then return false, "doppio binario " .. i .. "-" .. (i + 1) .. ": " .. tostring(SB.error) end
		for _, e in ipairs(SA.edges) do builtEdges[#builtEdges + 1] = e end
		for _, e in ipairs(SB.edges) do builtEdges[#builtEdges + 1] = e end
		local okD, D = CC.linkDouble({ SA.a, SA.b }, { SB.a, SB.b }, log, "doppio binario " .. i .. "-" .. (i + 1), builtEdges)
		if not okD then return false, D end
		for _, w in ipairs(D.warnings) do warnings[#warnings + 1] = w end
	end
	local ok, link = CC.finishRailLink(stations, used, log, built, loco, { bothWays = true, builtEdges = builtEdges })
	if ok then link.warnings = warnings end
	return ok, link
end

-- ---------------------------------------------------------------- binario d'incrocio / d'attesa
-- Dall'estremo E: diramazione, due binari paralleli lunghi len, riunione in uno scambio. Un treno aspetta su un
-- binario mentre l'altro passa (incrocio su binario unico, attesa prima di una stazione piena).
-- Segnali a doppio senso all'ingresso dei due binari (blocchi separati). Ritorna il nuovo estremo d'uscita.
function CC.buildPassingLoop(E, len)
	len = len or 400
	local edges = {}
	local okS, S = CC.buildSplit(E)
	if not okS then return false, { error = tostring(S.error) } end
	for _, e in ipairs(S.edges) do edges[#edges + 1] = e end
	local okA, A = CC.extendTrack(S.a, len)
	if not okA then return false, { error = tostring(A.error), edges = edges } end
	for _, e in ipairs(A.edges) do edges[#edges + 1] = e end
	local okB, B = CC.extendTrack(S.b, len)
	if not okB then return false, { error = tostring(B.error), edges = edges } end
	for _, e in ipairs(B.edges) do edges[#edges + 1] = e end
	local okT, T = CC.buildThroat(A.endInfo, B.endInfo, CC.SPLIT_LEN)
	if not okT then return false, { error = "uscita del binario d'incrocio: " .. tostring(T.error), edges = edges } end
	for _, e in ipairs(T.edges) do edges[#edges + 1] = e end
	local okSig, Sig = CC.addSignals({ A.edges[1], B.edges[1] }, { every = 1, oneWay = false, from = { x = E.x, y = E.y } })
	CC.remapEdges(edges, okSig and Sig.edges)
	return true, { exit = T.endInfo, edges = edges, signals = okSig and Sig.signals or 0, warning = (not okSig) and Sig.error or nil }
end

-- ---------------------------------------------------------------- ordine delle citta' in un anello
-- Giro piu' corto (vicino piu' vicino + miglioramento 2-opt). pts: lista di { x, y }. Ritorna gli indici, dal primo.
function CC.orderRing(pts)
	local n = #pts
	local order = {}
	for i = 1, n do order[i] = i end
	if n <= 3 then return order end
	local function d(i, j) return math.sqrt((pts[i].x - pts[j].x) ^ 2 + (pts[i].y - pts[j].y) ^ 2) end
	local visited, cur = { [1] = true }, 1
	order = { 1 }
	for _ = 2, n do
		local best, bd
		for j = 1, n do
			if not visited[j] and (not bd or d(cur, j) < bd) then best, bd = j, d(cur, j) end
		end
		visited[best] = true
		order[#order + 1] = best
		cur = best
	end
	local improved, guard = true, 0
	while improved and guard < 100 do
		improved, guard = false, guard + 1
		for i = 2, n - 1 do
			for k = i + 1, n do
				local a, b = order[i - 1], order[i]
				local c, e = order[k], order[k % n + 1]
				if d(a, b) + d(c, e) > d(a, c) + d(b, e) + 1e-6 then
					local lo, hi = i, k
					while lo < hi do order[lo], order[hi] = order[hi], order[lo]; lo, hi = lo + 1, hi - 1 end
					improved = true
				end
			end
		end
	end
	return order
end

-- ---------------------------------------------------------------- ferrovia ad anello
-- Stazioni in tutte le citta' (nell'ordine del giro piu' corto), binari che chiudono l'anello, deposito accanto
-- alla prima stazione (da quel lato i binari della stazione non si uniscono: uno va all'anello, uno al deposito),
-- linea nei due sensi (both_directions, default si'), treni distribuiti lungo il giro.
local function buildRing(a, built, builtEdges)
	local towns = {}
	for i, t in ipairs(a.town_ids) do towns[i] = t end
	if #towns < 3 then return { ok = false, error = "per un anello servono almeno 3 citta'" } end
	local C = {}
	for i, t in ipairs(towns) do C[i] = townCenter(t) end
	if a.reorder ~= false then
		local ord = CC.orderRing(C)
		local t2, c2 = {}, {}
		for k, i in ipairs(ord) do t2[k], c2[k] = towns[i], C[i] end
		towns, C = t2, c2
	end
	local n = #towns
	local both = a.both_directions ~= false
	local perDir = math.max(1, math.min(4, a.trains_per_direction or 1))
	local nCars = a.num_cars or 3
	local trainLen = CC.estimateTrainLength(nCars)
	local log, stations, notes = {}, {}, {}
	for i, t in ipairs(towns) do
		local prev, nxt = C[(i - 2) % n + 1], C[i % n + 1]
		local dx, dy = unit6(nxt.x - prev.x, nxt.y - prev.y)
		local plan = CC.planStation({ kind = "passengers", lines = both and 2 or 1, trains = perDir * (both and 2 or 1),
			train_len = trainLen, double = a.double_track })
		local merge = { f = true, b = true }
		if a.double_track then
			-- VERIFICATO p35/p36 (08.10.2026): la diramazione subito fuori dagli scambi della stazione collide con la
			-- gola della stazione. Doppio binario = due binari della stazione NON uniti, ognuno prosegue come un binario
			-- dell'anello (uno per senso). Stazione 1: un terzo binario per il deposito.
			merge = { f = false, b = false }
			plan.tracks = (i == 1) and 3 or 2
			plan.through = 0
			plan.layout = CC.stationLayout(plan.tracks, 0)
		elseif i == 1 then
			merge.b = false
			if plan.tracks < 2 then plan.tracks = 2; plan.layout = CC.stationLayout(plan.tracks, plan.through) end
		end
		local tname = CC.nameOf(t) or ("citta' " .. i)
		local st, info = CC.placeStationSmart(C[i], dx, dy, { prev, nxt }, tname .. " stazione", plan, {
			merge = merge, min_tracks = a.double_track and plan.tracks or ((i == 1) and 2 or nil),
			score = function(x, y) return CC.townBuildingsNear(x, y, 300) * 10 - math.sqrt((x - C[i].x) ^ 2 + (y - C[i].y) ^ 2) / 100 end,
		})
		if not st then return { ok = false, error = "non trovo spazio per la stazione di " .. tname, log = info and info.steps, alternatives = info and info.alternatives } end
		if info.needs_feeder then notes[#notes + 1] = tname .. ": stazione lontana dal centro, serve la navetta" end
		if info.shorter then trainLen = math.min(trainLen, info.max_train_len) end
		st.town = t
		stations[i] = st
		built[#built + 1] = st.construction
		for _, e in ipairs(st.edges or {}) do builtEdges[#builtEdges + 1] = e end
		log[#log + 1] = tname .. ": stazione con " .. info.plan.tracks .. " binari, " .. info.plan.length .. " m"
	end
	local warnings = {}
	for i = 1, n do
		local j = i % n + 1
		local sa, sb = stations[i], stations[j]
		local fromEnd = sa.sides.f[1]
		local label = "anello " .. i .. "-" .. j
		if a.double_track then
			if #sa.sides.f < 2 or #sb.sides.b < 2 then return { ok = false, error = label .. ": stazioni senza due binari liberi", log = log } end
			-- VERIFICATO p35 (08.10.2026): collegando subito gli estremi della stazione -> "Curvatura eccessiva".
			-- Prima un tratto dritto (come la gola delle stazioni a binario unico), poi la curva.
			local function straight(E)
				local okX, X = CC.extendTrack(E, CC.RING_LEAD or 140)
				if not okX then return nil, X.error end
				for _, e in ipairs(X.edges) do builtEdges[#builtEdges + 1] = e end
				return X.endInfo
			end
			local As, Bs = {}, {}
			for k = 1, 2 do
				local ea, errA = sa.leadF and sa.leadF[k] or straight(sa.sides.f[k])
				if not ea then return { ok = false, error = label .. ": tratto dritto in uscita: " .. tostring(errA), log = log } end
				sa.leadF = sa.leadF or {}; sa.leadF[k] = ea
				local eb, errB = sb.leadB and sb.leadB[k] or straight(sb.sides.b[k])
				if not eb then return { ok = false, error = label .. ": tratto dritto in entrata: " .. tostring(errB), log = log } end
				sb.leadB = sb.leadB or {}; sb.leadB[k] = eb
				As[k], Bs[k] = ea, eb
			end
			local okD, D = CC.linkDouble(As, Bs, log, label, builtEdges)
			if not okD then return { ok = false, error = D, log = log } end
			for _, w in ipairs(D.warnings) do warnings[#warnings + 1] = w end
		else
			local okL, info = CC.linkTwoEnds(fromEnd, sb.sides.b[1], log, label)
			if not okL then return { ok = false, error = label .. ": " .. tostring(info.error), log = log } end
			for _, e in ipairs(info.edges or {}) do builtEdges[#builtEdges + 1] = e end
		end
	end
	local depotEnd = a.double_track and stations[1].sides.b[3] or stations[1].sides.b[#stations[1].sides.b]
	-- tutti gli estremi delle stazioni sono gia' collegati all'anello, tranne quello per il deposito
	local used = {}
	for _, st in ipairs(stations) do for _, e in ipairs(st.ends) do if e ~= depotEnd then used[e.node] = true end end end
	local okF, link = CC.finishRailLink(stations, used, log, built, nil, {
		depotEnd = depotEnd, depotName = "Deposito " .. (CC.nameOf(towns[1]) or ""), ring = true, bothWays = both, builtEdges = builtEdges })
	if not okF then return { ok = false, error = link, log = log } end
	local groups = {}
	for i, st in ipairs(stations) do groups[i] = st.group end
	local names = {}
	for _, t in ipairs(towns) do names[#names + 1] = CC.nameOf(t) or "?" end
	local base = a.name or ("Anello " .. table.concat(names, " - "))
	local lines, trains, errs = {}, {}, {}
	local patterns = both and { { "ring", " (orario)" }, { "ring_reverse", " (antiorario)" } } or { { "ring", "" } }
	for _, pt in ipairs(patterns) do
		local stops = CC.lineStopOrder(groups, pt[1])
		local okL, li = CC.createLine(base .. pt[2], stops)
		if not okL then errs[#errs + 1] = "linea" .. pt[2] .. " non creata"
		else
			lines[#lines + 1] = li.line
			for k = 1, perDir do
				local okT, T = CC.buyPassengerTrain(link.depot, li.line, nCars, CC.staggerStop(k, perDir, #stops), trainLen, link.loco)
				if okT then trains[#trains + 1] = T.vehicle else errs[#errs + 1] = T.error end
			end
		end
	end
	return { ok = #lines > 0 and #trains > 0 and #errs == 0, line_id = lines[1], line_ids = lines, stations = groups,
		towns_order = towns, depot_id = link.depot, trains = trains, errors = errs, warnings = warnings, notes = notes, log = log }
end

SIM_ACTIONS.build_rail_ring = function(a)
	CC.need(a, { town_ids = "ids", both_directions = "bool?", trains_per_direction = "int?", num_cars = "int?",
		double_track = "bool?", reorder = "bool?", name = "str?" })
	local built, builtEdges = {}, {}
	CC.trackOverride = nil
	local ok, r = pcall(buildRing, a, built, builtEdges)
	if not ok then r = { ok = false, error = tostring(r) } end
	if not r.ok and not r.line_id then
		r.cleanup, r.leftovers = CC.rollback(built, builtEdges)
	end
	CC.trackOverride = nil
	return r
end
-- ===================================================================== fine b6
-- ===================================================================== BOZZA (NON TESTATO) - b7 linee e merci
-- Linee da stazioni esistenti (avanti e indietro, anello nei due sensi), linee merci a piu' fermate (raccolta da piu'
-- industrie, consegna in piu' punti, carico al ritorno, vagoni misti), stazioni ferroviarie singole e raccordi su
-- binari esistenti (traffico misto passeggeri + merci sugli stessi binari).
-- DA VERIFICARE in gioco: prove p11, p14, p18 (raccordo: divisione di un binario esistente).

-- ---------------------------------------------------------------- ordine delle fermate
-- back_forth: A B C D -> A B C D C B (il treno ferma anche al ritorno; con solo A B resta A B)
-- ring: A B C D (dopo D torna ad A) ; ring_reverse: A D C B (stesso anello nel verso opposto)
function CC.lineStopOrder(groups, pattern)
	local out = {}
	for i, g in ipairs(groups) do out[i] = g end
	local n = #groups
	if pattern == "back_forth" then
		for i = n - 1, 2, -1 do out[#out + 1] = groups[i] end
	elseif pattern == "ring_reverse" then
		out = { groups[1] }
		for i = n, 2, -1 do out[#out + 1] = groups[i] end
	end
	return out
end

-- Id di una merce dal nome (come in state.lua / get_overview), senza distinzione di maiuscole.
function CC.cargoIdByName(name)
	if not name then return nil end
	local found
	pcall(function()
		api.res.cargoTypeRep.forEachCargoType(nil, function(id)
			if not found and tostring(CC.cargoName(id)):lower() == tostring(name):lower() then found = id end
		end)
	end)
	if found then return found end
	for id = 0, 60 do
		local okN, n = pcall(CC.cargoName, id)
		if okN and n and tostring(n):lower() == tostring(name):lower() then return id end
	end
	return nil
end

-- Mezzi che possono servire un gruppo di stazioni: { rail = true, road = true, water = true, air = true }
function CC.groupCarriers(g)
	local C = api.type.enum.Carrier
	local out = {}
	pcall(function()
		local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
		for _, c in ipairs(CC.each(car[1])) do
			if c == C.RAIL then out.rail = true elseif c == C.ROAD then out.road = true
			elseif C.WATER and c == C.WATER then out.water = true elseif C.AIR and c == C.AIR then out.air = true end
		end
	end)
	return out
end

-- Composizione di un treno: locomotiva + nCars carri/carrozze. cargos: lista di merci (vagoni misti, a turno);
-- vuota = carrozze passeggeri. maxLen: il treno non supera il marciapiede (si tolgono carri in fondo).
function CC.trainModels(loco, nCars, cargos, maxLen)
	local models = { loco.id }
	local missing = {}
	for c = 1, nCars do
		local car
		if cargos and #cargos > 0 then
			local cg = cargos[(c - 1) % #cargos + 1]
			car = CC.pickModelForCargo("waggon", cg)
			if not car then missing[CC.cargoName(cg)] = true end
		else
			car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true })
		end
		if car then models[#models + 1] = car.id end
	end
	while maxLen and #models > 2 and CC.compositionLength(models) > maxLen do models[#models] = nil end
	local miss = {}
	for k in pairs(missing) do miss[#miss + 1] = k end
	return models, miss
end

-- ---------------------------------------------------------------- linea da stazioni esistenti
-- station_ids nell'ordine del percorso; pattern back_forth (default) o ring; both_directions: anche il verso
-- opposto (solo ring). vehicle: auto | bus | tram | truck | train | ship | plane. cargo: nome della merce (treni,
-- camion); count veicoli per linea, distribuiti lungo la linea.
SIM_ACTIONS.create_line_from_stations = function(a)
	CC.need(a, { station_ids = "ids", pattern = "str?", both_directions = "bool?", vehicle = "str?", count = "int?",
		num_cars = "int?", cargo = "str?", name = "str?" })
	local groups = a.station_ids
	if #groups < 2 then return { ok = false, error = "servono almeno 2 stazioni" } end
	local pattern = a.pattern or "back_forth"
	if pattern ~= "back_forth" and pattern ~= "ring" then return { ok = false, error = "pattern: back_forth oppure ring" } end
	local kind = a.vehicle or "auto"
	local car = CC.groupCarriers(groups[1])
	if kind == "auto" then
		kind = car.rail and "train" or (car.water and "ship" or (car.air and "plane" or (a.cargo and "truck" or "bus")))
	end
	local cargoId
	if a.cargo then
		cargoId = CC.cargoIdByName(a.cargo)
		if not cargoId then return { ok = false, error = "merce sconosciuta: " .. a.cargo } end
	end
	local patterns = { pattern }
	if a.both_directions and pattern == "ring" then patterns[2] = "ring_reverse" end
	local lines, vehicles, errs, fleets = {}, {}, {}, {}
	for idx, pt in ipairs(patterns) do
		local stops = CC.lineStopOrder(groups, pt)
		local okL, li = CC.createLine((a.name or "Linea") .. (idx == 2 and " (verso opposto)" or ""), stops)
		if not okL then errs[#errs + 1] = "linea non creata"; break end
		lines[#lines + 1] = li.line
		local depot = CC.depotForLine(li.line)
		if not depot then
			-- le linee senza veicoli non hanno ancora modi: provo i depositi del tipo giusto per distanza
			local p = CC.posOf(groups[1])
			local bestD, bd
			for _, d in ipairs(CC.playerDepots()) do
				local f = d.file
				local okKind = (kind == "train" and f:find("rail", 1, true)) or ((kind == "bus" or kind == "truck") and f:find("road_depot", 1, true))
					or (kind == "tram" and f:find("tram", 1, true)) or (kind == "ship" and f:find("water", 1, true))
				if okKind and d.x and p then
					local dist = math.sqrt((d.x - p.x) ^ 2 + (d.y - p.y) ^ 2)
					if not bd or dist < bd then bestD, bd = d.depot, dist end
				end
			end
			depot = bestD
		end
		if not depot then errs[#errs + 1] = "nessun deposito per la linea: usa build_depot"; break end
		if kind == "train" then
			-- treni: la stima e' solo un'indicazione; senza numero esplicito al massimo 2 (binario unico: si bloccherebbero)
			local est, fleet = CC.initialFleet(stops, nil, "train", a.count, 20)
			local count = a.count and est or math.min(est, 2)
			if not a.count and est > count then fleet.note = "stima " .. est .. " treni: messi " .. count .. " (binario unico); aggiungerli su richiesta" end
			fleets[#fleets + 1] = fleet
			local loco = CC.pickLocomotive(CC.railEra().catenary)
			if not loco then errs[#errs + 1] = "nessuna locomotiva disponibile"; break end
			local models, miss = CC.trainModels(loco, math.max(1, math.min(12, a.num_cars or 4)), cargoId and { cargoId } or nil, a.max_train_len)
			if #miss > 0 then errs[#errs + 1] = "nessun carro per: " .. table.concat(miss, ", ") end
			for k = 1, count do
				local okB, veh, warn = CC.buyComposition(depot, models, li.line, CC.staggerStop(k, count, #stops))
				if okB then vehicles[#vehicles + 1] = veh; if warn then errs[#errs + 1] = warn end else errs[#errs + 1] = tostring(veh); break end
			end
		else
			local folder = ({ bus = "bus", tram = "tram", truck = "truck", ship = CC.VEHICLE_FOLDERS.ship, plane = CC.VEHICLE_FOLDERS.plane })[kind]
			if not folder then errs[#errs + 1] = "tipo di veicolo sconosciuto: " .. tostring(kind); break end
			local model = cargoId and CC.pickModelForCargo(folder, cargoId) or CC.pickModel(folder, nil, { passengers = true })
			if not model then errs[#errs + 1] = "nessun veicolo " .. folder .. " disponibile"; break end
			local count, fleet = CC.initialFleet(stops, model.id, kind, a.count, 20)
			fleets[#fleets + 1] = fleet
			local okV, v = CC.buyVehicles(depot, model.id, count, li.line)
			for _, x in ipairs(v.vehicles or {}) do vehicles[#vehicles + 1] = x end
			for _, e in ipairs(v.errors or {}) do errs[#errs + 1] = e end
		end
	end
	return { ok = #lines == #patterns and #vehicles > 0 and #errs == 0, line_id = lines[1], line_ids = lines, vehicles = vehicles,
		vehicle = kind, errors = errs, fleet = fleets[1], fleets = fleets }
end

-- ---------------------------------------------------------------- linee merci a piu' fermate
-- Ordine "vicino piu' vicino" a partire da start (indici in pts), per non fare giri inutili.
local function nearestChain(pts, startPt)
	local left, out = {}, {}
	for i = 1, #pts do left[i] = true end
	local cur = startPt
	for _ = 1, #pts do
		local best, bd
		for i in pairs(left) do
			local d = (pts[i].x - cur.x) ^ 2 + (pts[i].y - cur.y) ^ 2
			if not bd or d < bd then best, bd = i, d end
		end
		left[best] = nil
		out[#out + 1] = best
		cur = pts[best]
	end
	return out
end

-- Scali di raccolta vicino alle industrie di partenza (pickup_ids), scali di consegna vicino alle destinazioni
-- (delivery_ids: industrie o citta'), binari in fila, deposito, una linea avanti e indietro, treni con vagoni per
-- tutte le merci in gioco (anche quelle che tornano indietro: return_cargo, default si').
local function buildCargoNet(a, built, builtEdges)
	local CT = api.type.ComponentType
	local P, D = a.pickup_ids, a.delivery_ids
	local cargos, seen, pairs_ = {}, {}, {}
	for _, p in ipairs(P) do
		for _, d in ipairs(D) do
			local cg = CC.cargoFor(p, d)
			if cg then
				pairs_[#pairs_ + 1] = (CC.nameOf(p) or "?") .. " -> " .. (CC.nameOf(d) or "?") .. ": " .. CC.cargoName(cg)
				if not seen[cg] then seen[cg] = true; cargos[#cargos + 1] = cg end
			end
			if a.return_cargo ~= false and CC.comp(d, CT.INDUSTRY) then
				local back = CC.cargoFor(d, p)
				if back and not seen[back] then
					seen[back] = true; cargos[#cargos + 1] = back
					pairs_[#pairs_ + 1] = (CC.nameOf(d) or "?") .. " -> " .. (CC.nameOf(p) or "?") .. ": " .. CC.cargoName(back) .. " (ritorno)"
				end
			end
		end
	end
	if #cargos == 0 then return { ok = false, error = "nessuna merce va dalle industrie di partenza alle destinazioni" } end
	-- ordine: raccolta, poi consegna
	local ents, pts = {}, {}
	local pP, pD = {}, {}
	for i, e in ipairs(P) do pP[i] = CC.industryAnchor(e) end
	for i, e in ipairs(D) do pD[i] = CC.industryAnchor(e) end
	for _, i in ipairs(nearestChain(pP, pP[1])) do ents[#ents + 1] = P[i]; pts[#pts + 1] = pP[i] end
	for _, i in ipairs(nearestChain(pD, pts[#pts])) do ents[#ents + 1] = D[i]; pts[#pts + 1] = pD[i] end
	local n = #ents
	if n < 2 then return { ok = false, error = "servono almeno 2 fermate" } end
	local nTrains = math.max(1, math.min(6, a.num_trains or 1))
	local nCars = math.max(1, math.min(16, a.num_cars or 6))
	local loco = CC.pickLocomotive(CC.railEra().catenary)
	if not loco then return { ok = false, error = "nessuna locomotiva disponibile" } end
	local models0, miss = CC.trainModels(loco, nCars, cargos)
	if #miss > 0 then return { ok = false, error = "nessun carro per: " .. table.concat(miss, ", ") } end
	local plan = CC.planStation({ kind = "cargo", trains = nTrains, cargo_types = #cargos, train_len = CC.compositionLength(models0) })
	local log, stations, notes = {}, {}, {}
	for i, e in ipairs(ents) do
		local prev, nxt = pts[i - 1], pts[i + 1]
		local dx, dy
		if nxt and prev then dx, dy = nxt.x - prev.x, nxt.y - prev.y
		elseif nxt then dx, dy = nxt.x - pts[i].x, nxt.y - pts[i].y
		else dx, dy = pts[i].x - prev.x, pts[i].y - prev.y end
		local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
		local nbs = {}
		if prev then nbs[#nbs + 1] = prev end
		if nxt then nbs[#nbs + 1] = nxt end
		local isTown = CC.comp(e, CT.TOWN) ~= nil
		local P0 = pts[i]
		local st, info = CC.placeStationSmart(P0, dx, dy, nbs, (CC.nameOf(e) or "Scalo") .. " scalo merci", plan, {
			Rs = isTown and { 250, 350, 500, 650 } or { 120, 180, 250, 350, 500 },
			score = isTown and function(x, y) return CC.townBuildingsNear(x, y, 300) end
				or function(x, y) return -math.sqrt((x - P0.x) ^ 2 + (y - P0.y) ^ 2) end,
			accept = function(inf)
				if isTown then
					if #CC.stationCatchables(inf.station) > 0 then return true end
					return false, "nessun edificio nel bacino"
				end
				if CC.stationCatches(inf.station, e) then return true end
				return false, "l'industria non e' nel bacino"
			end,
		})
		if not st then return { ok = false, error = "nessun posto per lo scalo di " .. (CC.nameOf(e) or "?"), log = info and info.steps, alternatives = info and info.alternatives } end
		st.town = isTown and e or nil
		stations[i] = st
		built[#built + 1] = st.construction
		for _, ed in ipairs(st.edges or {}) do builtEdges[#builtEdges + 1] = ed end
		log[#log + 1] = (CC.nameOf(e) or "?") .. ": scalo con " .. info.plan.tracks .. " binari, " .. info.plan.length .. " m"
		plan.max_len = math.min(plan.max_len or 1e9, info.plan.length - 10)
	end
	-- treni in piu' dei binari dei capolinea: binario d'attesa fuori dai capolinea
	local waitLoops
	if nTrains > plan.tracks then waitLoops = { [1] = true, [n] = true }; notes[#notes + 1] = "binari d'attesa fuori dai capolinea" end
	local lopts = { waitLoops = waitLoops }
	local okL, link = CC.linkStations(stations, log, builtEdges, built, loco, lopts)
	if not okL then return { ok = false, error = link, log = log } end
	if (lopts.waitLoopsFailed or 0) > 0 and nTrains > plan.tracks then
		notes[#notes + 1] = "niente spazio per i binari d'attesa: " .. plan.tracks .. " treno/i invece di " .. nTrains .. " (si possono aggiungere dopo un binario d'incrocio)"
		nTrains = plan.tracks
	end
	local groups = {}
	for i, st in ipairs(stations) do groups[i] = st.group end
	local stops = CC.lineStopOrder(groups, "back_forth")
	local names = {}
	for _, cg in ipairs(cargos) do names[#names + 1] = CC.cargoName(cg) end
	local okLine, li = CC.createLine(a.name or ("Merci: " .. table.concat(names, ", ")), stops)
	if not okLine then return { ok = false, error = li.error, log = log } end
	local models = CC.trainModels(loco, nCars, cargos, plan.max_len)
	if #models - 1 < nCars then notes[#notes + 1] = "treni accorciati a " .. (#models - 1) .. " carri per stare nei marciapiedi" end
	local trains, errs = {}, {}
	for k = 1, nTrains do
		local okB, veh, warn = CC.buyComposition(link.depot, models, li.line, CC.staggerStop(k, nTrains, #stops))
		if okB then trains[#trains + 1] = veh; if warn then errs[#errs + 1] = warn end else errs[#errs + 1] = tostring(veh); break end
	end
	return { ok = #trains > 0 and #errs == 0, line_id = li.line, stations = groups, depot_id = link.depot, trains = trains,
		cargo = names, flows = pairs_, cars = #models - 1, notes = notes, errors = errs, log = log }
end

SIM_ACTIONS.build_cargo_rail_network = function(a)
	CC.need(a, { pickup_ids = "ids", delivery_ids = "ids", num_trains = "int?", num_cars = "int?", return_cargo = "bool?", name = "str?" })
	local built, builtEdges = {}, {}
	CC.trackOverride = nil
	local ok, r = pcall(buildCargoNet, a, built, builtEdges)
	if not ok then r = { ok = false, error = tostring(r) } end
	if not r.ok and not r.line_id then
		r.cleanup, r.leftovers = CC.rollback(built, builtEdges)
	end
	CC.trackOverride = nil
	return r
end

-- ---------------------------------------------------------------- raccordo su un binario esistente
-- Divide un binario esistente al parametro sv (0..1) e ne fa partire una diramazione verso `side` (1 sinistra,
-- -1 destra rispetto al verso node0 -> node1). Serve per collegare uno scalo o una stazione nuova a una linea gia'
-- costruita (traffico misto). DA VERIFICARE: la divisione dei binari (la funzione per le strade e' verificata).
function CC.branchFromTrack(e, sv, side, L, lat)
	local CT = api.type.ComponentType
	local be = CC.comp(e, CT.BASE_EDGE)
	if not be then return false, { error = "binario inesistente" } end
	if CC.inConstruction and CC.inConstruction(e) then return false, { error = "il binario fa parte di una costruzione" } end
	local tmplName = tostring(be.roadTemplate)
	local tmpl = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(tmplName))
	local p0, p1, t0, t1 = be.position0, be.position1, be.tangent0, be.tangent1
	-- punto sulla curva (Hermite cubica, come nel gioco)
	local s = sv
	local h00, h10, h01, h11 = 2 * s ^ 3 - 3 * s ^ 2 + 1, s ^ 3 - 2 * s ^ 2 + s, -2 * s ^ 3 + 3 * s ^ 2, s ^ 3 - s ^ 2
	local qx = h00 * p0.x + h10 * t0.x + h01 * p1.x + h11 * t1.x
	local qy = h00 * p0.y + h10 * t0.y + h01 * p1.y + h11 * t1.y
	local d00, d10, d01, d11 = 6 * s ^ 2 - 6 * s, 3 * s ^ 2 - 4 * s + 1, -6 * s ^ 2 + 6 * s, 3 * s ^ 2 - 2 * s
	local qdx = d00 * p0.x + d10 * t0.x + d01 * p1.x + d11 * t1.x
	local qdy = d00 * p0.y + d10 * t0.y + d01 * p1.y + d11 * t1.y
	local qz = p0.z + (p1.z - p0.z) * sv
	local ql = math.sqrt(qdx * qdx + qdy * qdy)
	local ux, uy = qdx / ql, qdy / ql
	L = L or CC.SPLIT_LEN
	local nx, ny = -uy * (side or 1), ux * (side or 1)
	-- fine della diramazione: avanti L e di lato lat m (default 12), con uscita parallela al binario
	lat = lat or 12
	local bx, by = qx + ux * L + nx * lat, qy + uy * L + ny * lat
	if CC.inMap and not CC.inMap(bx, by, 150) then return false, { error = "diramazione fuori dai confini della mappa" } end
	local function seg(id, n0, a0, ta, n1, a1, tb)
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = id; sg.type = 1
		sg.comp.node0 = n0; sg.comp.node1 = n1
		sg.comp.position0 = a0; sg.comp.position1 = a1; sg.comp.tangent0 = ta; sg.comp.tangent1 = tb
		sg.comp.type = 0; sg.comp.typeIndex = -1
		sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = tmplName; sg.comp.roadStyle = tmpl.streetStyle
		sg.comp.roadType = api.type.enum.RoadType.TRACK
		return sg
	end
	local Q = api.type.Vec3f.new(qx, qy, qz)
	local B = api.type.Vec3f.new(bx, by, qz)
	local nQ, nB = api.type.NodeAndEntity.new(), api.type.NodeAndEntity.new()
	nQ.entity = -1; nQ.comp.position = Q
	nB.entity = -2; nB.comp.position = B
	local dB = math.sqrt((bx - qx) ^ 2 + (by - qy) ^ 2)
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.nodesToAdd = { nQ, nB }
	prop.streetProposal.edgesToAdd = {
		seg(-3, be.node0, api.type.Vec3f.new(p0.x, p0.y, p0.z), api.type.Vec3f.new(t0.x * sv, t0.y * sv, qz - p0.z), -1, Q,
			api.type.Vec3f.new(qdx * sv, qdy * sv, qz - p0.z)),
		seg(-4, -1, Q, api.type.Vec3f.new(qdx * (1 - sv), qdy * (1 - sv), p1.z - qz), be.node1, api.type.Vec3f.new(p1.x, p1.y, p1.z),
			api.type.Vec3f.new(t1.x * (1 - sv), t1.y * (1 - sv), p1.z - qz)),
		seg(-5, -1, Q, api.type.Vec3f.new(ux * dB, uy * dB, 0), -2, B, api.type.Vec3f.new(ux * dB, uy * dB, 0)),
	}
	prop.streetProposal.edgesToRemove = { e }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = "raccordo: " .. tostring(cmd) } end
	local ok, _, ents = CC.send(cmd)
	if not ok then return false, { error = "raccordo rifiutato" } end
	local edges = {}
	for _, en in ipairs(ents or {}) do if CC.comp(en, CT.BASE_EDGE) then edges[#edges + 1] = en end end
	local node = CC.nodeAt(bx, by)
	if not node then return false, { error = "estremo del raccordo non trovato", edges = edges } end
	return true, { endInfo = { node = node, x = bx, y = by, z = qz, dx = ux, dy = uy }, edges = edges }
end

-- Binario del giocatore piu' vicino a (x, y) entro r (fuori dalle costruzioni), con il punto migliore (sv).
function CC.nearestTrack(x, y, r)
	local CT = api.type.ComponentType
	local best
	pcall(function()
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE))) do
			local be = CC.comp(e, CT.BASE_EDGE)
			if be and tostring(be.roadTemplate):find("/track/", 1, true) and not (CC.inConstruction and CC.inConstruction(e)) then
				for _, sv in ipairs({ 0.25, 0.5, 0.75 }) do
					local px = be.position0.x + (be.position1.x - be.position0.x) * sv
					local py = be.position0.y + (be.position1.y - be.position0.y) * sv
					local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
					if not best or d < best.d then best = { edge = e, sv = sv, d = d, x = px, y = py } end
				end
			end
		end
	end)
	return best
end

-- Stazione ferroviaria singola (passeggeri o merci) vicino a un'entita', dimensionata con CC.planStation,
-- e (connect = true, default) raccordo al binario del giocatore piu' vicino entro 3 km.
SIM_ACTIONS.build_rail_station = function(a)
	CC.need(a, { near_id = "id", kind = "str?", trains = "int?", lines = "int?", train_len = "int?", connect = "bool?", name = "str?" })
	local CT = api.type.ComponentType
	local log = {}
	local P0 = CC.posOf(a.near_id)
	if not P0 then return { ok = false, error = "posizione non trovata" } end
	local kind = a.kind == "cargo" and "cargo" or "passengers"
	local plan = CC.planStation({ kind = kind, trains = a.trains or 1, lines = a.lines or 1, train_len = a.train_len or CC.estimateTrainLength(4) })
	local track = CC.nearestTrack(P0.x, P0.y, 3000)
	local dx, dy = 1, 0
	if track then
		local be = CC.comp(track.edge, CT.BASE_EDGE)
		dx, dy = be.position1.x - be.position0.x, be.position1.y - be.position0.y
		local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	end
	local isInd = CC.comp(a.near_id, CT.INDUSTRY) ~= nil
	local st, info = CC.placeStationSmart(P0, dx, dy, track and { { x = track.x, y = track.y } } or {}, a.name or ((CC.nameOf(a.near_id) or "") .. " stazione"), plan, {
		Rs = isInd and { 120, 180, 250, 350, 500 } or nil,
		accept = isInd and function(inf)
			if CC.stationCatches(inf.station, a.near_id) then return true end
			return false, "l'industria non e' nel bacino"
		end or nil,
		score = (not isInd) and function(x, y) return CC.townBuildingsNear(x, y, 300) * 10 end or nil,
	})
	if not st then return { ok = false, error = "nessun posto per la stazione", log = info and info.steps, alternatives = info and info.alternatives, reuse_group = info and info.reuse_group } end
	local res = { ok = true, station_id = st.group, tracks = info.plan.tracks, length = info.plan.length, notes = {} }
	if a.connect ~= false then
		if not track then
			res.notes[#res.notes + 1] = "nessun binario entro 3 km: stazione non collegata"
		else
			local side = ((st.site.x - track.x) * -dy + (st.site.y - track.y) * dx) >= 0 and 1 or -1
			local okB, B = CC.branchFromTrack(track.edge, track.sv, side)
			if not okB then
				res.ok = false; res.error = "stazione costruita ma raccordo fallito: " .. tostring(B.error)
			else
				local e = CC.endToward(st, B.endInfo.x, B.endInfo.y)
				local okL, L = CC.linkTwoEnds(B.endInfo, e, log, "raccordo")
				if not okL then res.ok = false; res.error = "stazione costruita ma binario di raccordo fallito: " .. tostring(L.error) end
			end
		end
	end
	res.log = log
	return res
end
-- ===================================================================== fine b7
-- ===================================================================== BOZZA (NON TESTATO) - b8 collaudo e mappa
-- Collaudo: dopo ogni costruzione (b9 lo chiama da solo) e su richiesta (check_line, check_network) controlla che
-- quello che e' stato costruito funzioni: percorso tra le fermate, veicoli presenti e in movimento, deposito che
-- raggiunge la linea, fermate con citta'/industrie nel bacino. Il middleware lo ripete dopo 1-2 mesi di gioco
-- (passeggeri/merci trasportati). Lettura della mappa per Claude (read_map).
-- DA VERIFICARE in gioco (sonda s9): stato dei veicoli, posizione dei veicoli, statistiche delle linee.

-- Campioni per capire se un veicolo si muove: posizione all'ultimo controllo (si perde se lo script viene ricreato:
-- in quel caso il movimento risulta "non ancora verificabile").
CC._samples = CC._samples or {}

-- Stato del veicolo come testo (IN_DEPOT, EN_ROUTE, AT_TERMINAL, GOING_TO_DEPOT ...). DA VERIFICARE i nomi.
function CC.vehicleState(v)
	local tv = CC.comp(v, api.type.ComponentType.TRANSPORT_VEHICLE)
	if not tv then return "?" end
	local s = tv.state
	local name = tostring(s)
	-- VERIFICATO (sonde s9 e p22): l'enum ha i nomi dentro __index (IN_DEPOT 0, EN_ROUTE 1, AT_TERMINAL 2, GOING_TO_DEPOT 3)
	local names = { [0] = "IN_DEPOT", [1] = "EN_ROUTE", [2] = "AT_TERMINAL", [3] = "GOING_TO_DEPOT" }
	pcall(function()
		local E = api.type.enum.TransportVehicleState
		local function scan(t) for k, val in pairs(t) do if type(val) == "table" then scan(val) elseif val == s then names[s] = k end end end
		scan(E)
	end)
	if type(s) == "number" and names[s] then name = names[s] end
	return name
end

-- Posizione di un veicolo: prova piu' fonti (DA VERIFICARE quale funziona: sonda s9).
function CC.vehiclePos(v)
	local p
	pcall(function() p = CC.posOf(v) end)
	if p then return p end
	pcall(function()
		local mp = CC.comp(v, api.type.ComponentType.MOVE_PATH)
		local d = mp.dyn
		p = { x = d.pathPos.x, y = d.pathPos.y }
	end)
	return p
end

-- Statistiche di una linea (passeggeri/merci trasportati, frequenza). I nomi dei campi non sono ancora noti:
-- provo quelli del gioco precedente. DA VERIFICARE con la sonda s9; quelli che non esistono restano nil.
function CC.lineStats(L)
	local st = {}
	local lc = CC.comp(L, api.type.ComponentType.LINE)
	for _, f in ipairs({ "itemsTransported", "transported", "frequency", "rate" }) do
		pcall(function() local v = lc[f]; if v ~= nil then st[f] = type(v) == "number" and v or tostring(v) end end)
	end
	pcall(function() st.frequency = st.frequency or api.engine.util.line.getFrequency(L) end)
	pcall(function() st.rate = st.rate or api.engine.util.line.getRate(L) end)
	pcall(function()
		local ent = game.interface.getEntity(L)
		if ent then
			st.itemsTransported = st.itemsTransported or ent.itemsTransported
			st.frequency = st.frequency or ent.frequency
		end
	end)
	return st
end

-- C'e' un'altra stazione del giocatore (gruppo diverso) entro r metri dal gruppo g? (scambio a piedi)
function CC.otherStationNear(g, r)
	local p = CC.posOf(g)
	if not p then return false end
	local found = false
	pcall(function()
		for _, st in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), r, api.type.ComponentType.STATION))) do
			local og = api.engine.system.stationGroupSystem.getStationGroup(st)
			if og and og ~= g and og >= 0 then found = true; break end
		end
	end)
	return found
end

-- Controllo di una linea. Ritorna { ok, problems = { testo }, suggestions = { testo }, ... }.
function CC.checkLine(L)
	local CT = api.type.ComponentType
	local r = { line_id = L, problems = {}, suggestions = {} }
	local lc = CC.comp(L, CT.LINE)
	if not lc then r.ok = false; r.problems[1] = "la linea non esiste"; return r end
	r.name = CC.nameOf(L)
	local groups = CC.lineGroups(L) or {}
	r.stops = #groups
	if #groups < 2 then r.problems[#r.problems + 1] = "la linea ha meno di 2 fermate" end
	local vs = CC.lineVehicles(L)
	r.vehicles = #vs
	if #vs == 0 then
		r.problems[#r.problems + 1] = "nessun veicolo sulla linea"
		r.suggestions[#r.suggestions + 1] = "aggiungere veicoli (add_vehicles o create_line_from_stations)"
	end
	-- modi della linea (o del primo veicolo)
	local modes = CC.lineModes(L)
	if #modes == 0 and vs[1] then
		pcall(function()
			for _, tm in ipairs(CC.each(api.res.modelRep.get(CC.vehicleModels(vs[1])[1]).metadata.transportVehicle.engineTransportModes)) do modes[#modes + 1] = tm end
		end)
	end
	-- percorso tra fermate consecutive (anche dall'ultima alla prima: la linea gira), con la stazione e il terminale
	-- indicati dalla fermata (VERIFICATO s14 sul salvataggio di terzi: nessun falso "nessun percorso")
	local stops = CC.lineStops(L)
	if #modes > 0 then
		for i = 1, #stops do
			local j = i % #stops + 1
			if stops[i].stationGroup ~= stops[j].stationGroup
				and not CC.hasPath(CC.lineStopNode(stops[i]), CC.lineStopNode(stops[j]), modes)
				and not CC.groupPath(stops[i].stationGroup, stops[j].stationGroup, modes) then
				r.problems[#r.problems + 1] = "nessun percorso dalla fermata " .. i .. " (" .. (CC.nameOf(groups[i]) or "?") .. ") alla " .. j
				r.suggestions[#r.suggestions + 1] = "collegare le due fermate (strada/binario mancante o senso unico)"
			end
		end
	end
	-- deposito
	if not CC.depotForLine(L) then
		r.problems[#r.problems + 1] = "nessun deposito raggiunge la linea"
		r.suggestions[#r.suggestions + 1] = "costruire un deposito collegato (build_depot)"
	end
	-- bacino delle fermate. VERIFICATO sul salvataggio di terzi (94 linee che funzionano): molte fermate non hanno
	-- edifici nel bacino ma servono da nodo di scambio (fermata bus davanti alla stazione, metropolitana, porti,
	-- monumenti). Una fermata senza bacino e' solo una nota se: il gruppo e' servito da altre linee, oppure c'e' un'altra
	-- stazione del giocatore entro 250 m. La linea ha un problema solo se meno di 2 fermate servono a qualcosa.
	local counts = CC._lineCounts or CC.groupLineCounts()
	r.notes = {}
	local useful = 0
	for i, g in ipairs(groups) do
		if CC.groupCatchables(g) > 0 then
			useful = useful + 1
		elseif (counts[g] or 0) > 1 or CC.otherStationNear(g, 250) then
			useful = useful + 1
			r.notes[#r.notes + 1] = "fermata " .. i .. " (" .. (CC.nameOf(g) or "?") .. "): nodo di scambio senza edifici nel bacino"
		else
			r.notes[#r.notes + 1] = "fermata " .. i .. " (" .. (CC.nameOf(g) or "?") .. "): nessun edificio o industria nel bacino"
		end
	end
	if #groups >= 2 and useful < 2 then
		r.problems[#r.problems + 1] = "meno di 2 fermate hanno edifici, industrie o coincidenze nel bacino: la linea trasporta poco o nulla"
		r.suggestions[#r.suggestions + 1] = "spostare le fermate verso il centro o collegarle con una navetta"
	end
	-- veicoli: stato e movimento rispetto all'ultimo controllo
	local states, still, moved, unknown = {}, 0, 0, 0
	local now = 0
	pcall(function() now = CC.comp(api.engine.util.getWorld(), CT.GAME_TIME).gameTime end)
	for _, v in ipairs(vs) do
		local s = CC.vehicleState(v)
		states[s] = (states[s] or 0) + 1
		local p = CC.vehiclePos(v)
		local prev = CC._samples[v]
		if p and prev and now > prev.t then
			if (p.x - prev.x) ^ 2 + (p.y - prev.y) ^ 2 < 4 and s ~= "AT_TERMINAL" and s ~= "IN_DEPOT" then still = still + 1 else moved = moved + 1 end
		else
			unknown = unknown + 1
		end
		if p then CC._samples[v] = { x = p.x, y = p.y, t = now } end
	end
	r.vehicle_states = states
	r.vehicles_moving = moved
	r.vehicles_still = still
	r.movement_unknown = unknown
	if still > 0 then
		r.problems[#r.problems + 1] = still .. " veicoli fermi dall'ultimo controllo"
		r.suggestions[#r.suggestions + 1] = "controllare blocchi (segnali, binario unico con troppi treni, strada interrotta)"
	end
	if (states.IN_DEPOT or 0) == #vs and #vs > 0 then
		r.problems[#r.problems + 1] = "tutti i veicoli sono ancora nel deposito"
	end
	r.stats = CC.lineStats(L)
	r.ok = #r.problems == 0
	return r
end

SIM_ACTIONS.check_line = function(a)
	CC.need(a, { line_id = "id" })
	return CC.checkLine(a.line_id)
end

-- Tutte le linee del giocatore: solo quelle con problemi (al massimo max_lines controllate).
SIM_ACTIONS.check_network = function(a)
	CC.need(a or {}, { max_lines = "int?" })
	local lines = {}
	pcall(function() lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer())) end)
	local bad, okN = {}, 0
	CC._lineCounts = CC.groupLineCounts()
	for i = 1, math.min(#lines, (a and a.max_lines) or 40) do
		local r = CC.checkLine(lines[i])
		if r.ok then okN = okN + 1 else bad[#bad + 1] = { line_id = r.line_id, name = r.name, problems = r.problems, suggestions = r.suggestions } end
	end
	CC._lineCounts = nil
	return { ok = true, lines_checked = math.min(#lines, (a and a.max_lines) or 40), lines_ok = okN, lines_with_problems = bad }
end

-- ---------------------------------------------------------------- lettura della mappa
-- Riassunto per pianificare: estensione, griglia di quote e acqua, citta' (con edifici = grandezza), industrie con
-- merci, linee esistenti. grid: punti per lato (4-16, default 10).
SIM_ACTIONS.read_map = function(a)
	CC.need(a or {}, { grid = "int?" })
	local CT = api.type.ComponentType
	local N = math.max(4, math.min(16, (a and a.grid) or 10))
	local minX, minY, maxX, maxY
	local function ext(p)
		if not p then return end
		minX = math.min(minX or p.x, p.x); maxX = math.max(maxX or p.x, p.x)
		minY = math.min(minY or p.y, p.y); maxY = math.max(maxY or p.y, p.y)
	end
	local towns, inds = {}, {}
	for _, t in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.TOWN))) do
		local p = CC.posOf(t)
		ext(p)
		if p then towns[#towns + 1] = { id = t, name = CC.nameOf(t), x = math.floor(p.x), y = math.floor(p.y), z = math.floor(p.z or 0),
			buildings = CC.townBuildingsNear(p.x, p.y, 700) } end
	end
	table.sort(towns, function(u, v) return u.buildings > v.buildings end)
	for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.INDUSTRY))) do
		local p = CC.posOf(e)
		ext(p)
		local ins, outs = CC.industryCargo(e)
		local inN, outN = {}, {}
		for _, c in ipairs(ins or {}) do inN[#inN + 1] = CC.cargoName(c) end
		for _, c in ipairs(outs or {}) do outN[#outN + 1] = CC.cargoName(c) end
		if p then inds[#inds + 1] = { id = e, name = CC.nameOf(e), x = math.floor(p.x), y = math.floor(p.y), inputs = inN, outputs = outN } end
	end
	if not minX then return { ok = false, error = "mappa vuota?" } end
	local pad = 1500
	minX, minY, maxX, maxY = minX - pad, minY - pad, maxX + pad, maxY + pad
	local heights, water = {}, {}
	for j = 0, N - 1 do
		local y = maxY - (maxY - minY) * j / (N - 1)
		local hrow, wrow = {}, {}
		for i = 0, N - 1 do
			local x = minX + (maxX - minX) * i / (N - 1)
			hrow[#hrow + 1] = math.floor((CC.heightAt(x, y) or 0) + 0.5)
			wrow[#wrow + 1] = CC.onWater(x, y) and "~" or "."
		end
		heights[#heights + 1] = hrow
		water[#water + 1] = table.concat(wrow)
	end
	local lines = {}
	pcall(function()
		for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
			lines[#lines + 1] = { id = L, name = CC.nameOf(L), stops = #(CC.lineGroups(L) or {}), vehicles = #CC.lineVehicles(L) }
		end
	end)
	return { ok = true, year = CC.year(), bounds = { minX = math.floor(minX), minY = math.floor(minY), maxX = math.floor(maxX), maxY = math.floor(maxY) },
		grid = N, heights = heights, water = water, water_legend = "righe da nord (y max) a sud, colonne da ovest a est; ~ acqua",
		towns = towns, industries = inds, lines = lines }
end
-- ===================================================================== fine b8
-- ===================================================================== BOZZA (NON TESTATO) - b9 (va caricata per ULTIMA)
-- Avvolge tutte le azioni:
--   - controllo degli argomenti anche nella mod (azioni gia' esistenti: tabella SPECS; quelle nuove lo fanno da sole);
--   - registro di cio' che costruiscono -> result.created (il middleware lo salva per "annulla");
--   - se un'azione stradale fallisce senza creare la linea, toglie depositi e costruzioni appena fatti
--     (le fermate e i binari del tram restano: sono pezzi di strade cittadine);
--   - collaudo subito dopo la costruzione: per ogni linea creata, CC.checkLine (b8) -> result.collaudo;
--   - avviso se la partita risulta in pausa.
local NO_TX = { undo = true, check_line = true, check_network = true, read_map = true }
local CLEANUP_ON_FAIL = { build_tram_line = true, build_bus_line = true, connect_industry_to_city = true,
	build_intercity_bus = true, connect_station_to_town = true, build_air_or_water_line = true }
-- argomenti delle azioni gia' esistenti (gli stessi degli schemi di middleware/tools.py)
local SPECS = {
	build_bus_line = { town_id = "id", num_stops = "int?", num_vehicles = "int?", name = "str?" },
	build_tram_line = { town_id = "id", num_stops = "int?", num_vehicles = "int?", name = "str?" },
	build_station = { kind = "str", near_entity_id = "id", name = "str?" },
	build_line = { name = "str", station_ids = "ids", transport = "str" },
	build_rail_line = { town_ids = "ids", num_trains = "int?", num_cars = "int?", name = "str?" },
	buy_and_assign_vehicles = { line_id = "id", count = "int", depot_id = "id?", model = "str?" },
	connect_industry_to_city = { industry_id = "id", target_id = "id", transport = "str?", num_vehicles = "int?" },
}

for name, f in pairs(SIM_ACTIONS) do
	if not NO_TX[name] then
		SIM_ACTIONS[name] = function(a)
			if SPECS[name] then
				local okN, errN = pcall(CC.need, a, SPECS[name])
				if not okN then
					return { ok = false, error = tostring(errN), created = { vehicles = {}, lines = {}, constructions = {}, tracks = {}, roads = {} } }
				end
			end
			CC.txBegin()
			local ok, r = pcall(f, a)
			local tx = CC.txEnd()
			if not ok then r = { ok = false, error = tostring(r) } end
			if type(r) ~= "table" then r = { ok = true, value = r } end
			local created = CC.txClassify(tx)
			-- pulizia prudente: niente rimozioni se l'azione ha fatto anche binari o (aerei/navi) strade d'accesso
			local risky = #created.tracks > 0 or (name == "build_air_or_water_line" and #created.roads > 0)
			if risky and CLEANUP_ON_FAIL[name] and not r.ok and not r.line_id then
				CC.noteLeftovers(created.constructions, created.tracks)
				r.leftovers = { constructions = created.constructions, edges = created.tracks }
			elseif CLEANUP_ON_FAIL[name] and not r.ok and not r.line_id and #created.constructions > 0 then
				local n = 0
				for i = #created.constructions, 1, -1 do
					if CC.removeConstruction(created.constructions[i]) then n = n + 1 end
				end
				r.cleanup = n .. " costruzioni rimosse (fermate e strade cittadine restano)"
				created = CC.txClassify(tx)
			end
			r.created = created
			-- collaudo subito: le linee create (o indicate nel risultato)
			local toCheck, seen = {}, {}
			for _, L in ipairs(r.line_ids or {}) do if not seen[L] then seen[L] = true; toCheck[#toCheck + 1] = L end end
			if r.line_id and not seen[r.line_id] then toCheck[#toCheck + 1] = r.line_id end
			if #toCheck > 0 and CC.checkLine then
				r.collaudo = {}
				for _, L in ipairs(toCheck) do
					local okC, C = pcall(CC.checkLine, L)
					r.collaudo[#r.collaudo + 1] = okC and { line_id = L, ok = C.ok, problems = C.problems, suggestions = C.suggestions }
						or { line_id = L, ok = false, problems = { "collaudo non eseguito: " .. tostring(C) } }
				end
			end
			if CC.gameSpeed() == 0 then r.warning = "la partita e' in pausa" end
			return r
		end
	end
end
-- ===================================================================== fine b9
-- ===================================================================== fine azioni

local SIMDEV = { log = {} }

local function simJob(state, name, param)
	local st = state:get() or {}
	st.jobs = st.jobs or {}
	local key = param and param.key or "?"
	local rec = { name = name, time = os.time() }
	if name == "action" then
		local a = param and param.action or {}
		local f = SIM_ACTIONS[a.type]
		if not f then
			rec.ok = false; rec.error = "azione sim sconosciuta: " .. tostring(a.type)
		else
			local ok, res = pcall(f, a)
			if ok then
				rec.ok = true; rec.value = toPlain(res)
			else
				rec.ok = false; rec.error = tostring(res)
			end
		end
	elseif name == "eval" and DEV_MODE then
		local env = setmetatable({ dev = SIMDEV, L = L, toPlain = toPlain }, { __index = _G })
		local f, err = load(param.code, "=capocantiere_sim_eval", "t", env)
		if not f then
			rec.ok = false; rec.error = "compilazione: " .. tostring(err)
		else
			local ok, res = pcall(f)
			rec.ok = ok
			if ok then rec.value = toPlain(res) else rec.error = tostring(res) end
		end
	else
		rec.ok = false; rec.error = "lavoro sconosciuto: " .. tostring(name)
	end
	st.jobs[key] = rec
	-- tengo solo gli ultimi 10 risultati (lo stato finisce nel salvataggio)
	local keys = {}
	for k, v in pairs(st.jobs) do keys[#keys + 1] = { k, v.time or 0 } end
	table.sort(keys, function(a, b) return a[2] > b[2] end)
	for i = 11, #keys do st.jobs[keys[i][1]] = nil end
	state:set(st)
end

local M = {
	update = function(_userParams, state, _dt)
		-- lato simulazione: app non e' disponibile qui. In sviluppo ci si iscrive agli eventi
		-- (TF3 li consegna agli script solo dopo subscribeToAllEvents, vedi game_time.script)
		if DEV_MODE then
			pcall(function()
				if not state:hasEventSubscriptions() then state:subscribeToAllEvents() end
			end)
		end
	end,
	handleEvent = function(_userParams, state, src, id, name, param)
		-- lavori inviati dalla GUI al lato simulazione (qui i comandi di costruzione funzionano
		-- come nelle missioni ufficiali; dalla GUI la conversione delle proposte con rimozioni fallisce)
		if id == "capocantiere" then
			pcall(function() simJob(state, name, param) end)
			return
		end
		if not DEV_MODE then return end
		pcall(function()
			local st = state:get() or {}
			st.seen = st.seen or {}
			local key = tostring(src) .. " | " .. tostring(id) .. " | " .. tostring(name)
			local found = false
			for _, k in ipairs(st.seen) do if k == key then found = true break end end
			if not found and #st.seen < 100 then st.seen[#st.seen + 1] = key end
			if not found then state:set(st) end
		end)
	end,
	guiUpdate = function(_userParams, stateReadOnly, guiState)
		pcall(function() SIM_SNAPSHOT = stateReadOnly:get() end)
		local ok, err = pcall(guiTick, guiState)
		if not ok then L("errore guiUpdate: " .. tostring(err)) end
		if DEV_MODE then
			pcall(function()
				local sim = SIM_SNAPSHOT
				local cap = sim and sim.lastCapture
				local g = guiState:get() or {}
				if cap and cap.seq ~= g.savedCaptureSeq then
					g.savedCaptureSeq = cap.seq
					guiState:set(g)
					app.saveUserdata(DIR, FP .. "captured_" .. tostring(os.time()) .. "_" .. tostring(cap.seq), cap)
					L("catturata costruzione: " .. cap.id .. " / " .. cap.name)
				end
			end)
		end
	end,
	guiHandleEvent = function(_userParams, _stateReadOnly, _guiState, src, id, name, param)
		local ok, err = pcall(captureEvent, src, id, name, param)
		if not ok then L("errore cattura evento: " .. tostring(err)) end
	end,
}

function data()
	return M
end

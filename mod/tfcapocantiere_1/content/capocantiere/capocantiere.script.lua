-- Capo Cantiere - mod Lua (passo 3: esportazione dello stato)
--
-- Risultati del test di I/O (passo 2), verificati in gioco:
--   * lato interfaccia (guiUpdate): app.saveUserdata / loadUserdata / getAllUserdata FUNZIONANO
--     e scrivono in <dati utente>/capocantiere/<nome>.lua
--   * lato simulazione (update): app NON e' disponibile, api.gui non esiste
--   * io, dofile, loadfile non esistono; os ha solo time/clock/date/getenv
-- Quindi tutto lo scambio di file avviene nel lato interfaccia. Da li' si legge lo stato
-- del motore (api.engine, sola lettura) e si inviano comandi con api.cmd.sendCommand.
--
-- Il gioco ricrea spesso lo stato Lua degli script: i dati che devono durare stanno
-- nello stato dello script (guiState:get()/set()), non in variabili locali.

local DIR = "capocantiere"
local EXPORT_INTERVAL = 10      -- secondi tra due esportazioni di state.lua
local STATE_VERSION = 1

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
	app.saveUserdata(DIR, "state", s)
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
	local prefix = "actions_" .. nextId .. "_"
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
	local nonce = tostring(req.nonce or fname:sub(#("actions_" .. nextId .. "_") + 1))

	L("eseguo richiesta azioni id " .. tostring(req.id))
	local results = {}
	for i, a in ipairs(req.actions or {}) do
		local h = type(a) == "table" and handlers[a.type] or nil
		local r
		if type(a) == "table" and SIM_TYPES[a.type] then
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
		app.saveUserdata(DIR, "results_" .. req.id .. "_" .. nonce, { id = req.id, nonce = nonce, results = results, finishedAt = os.time() })
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
			app.saveUserdata(DIR, "results_" .. p.id .. "_" .. p.nonce, { id = p.id, nonce = p.nonce, results = p.results, finishedAt = now })
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

	if not g.lastExport or now - g.lastExport >= EXPORT_INTERVAL then
		g.lastExport = now
		g.exports = (g.exports or 0) + 1
		changed = true
		local ok, st, dt = pcall(exportState)
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
-- della proposta in capocantiere/captured_<n>.lua: serve a imparare il formato corretto
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
	local fn = "captured_" .. tostring(os.time()) .. "_" .. tostring(DEV.captureCount)
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
		sg.type = 1
		sg.comp.node0 = q0.id; sg.comp.node1 = q1.id
		sg.comp.position0 = api.type.Vec3f.new(q0.x, q0.y, q0.z); sg.comp.position1 = api.type.Vec3f.new(q1.x, q1.y, q1.z)
		sg.comp.tangent0 = api.type.Vec3f.new(d0x * dt, d0y * dt, dz); sg.comp.tangent1 = api.type.Vec3f.new(d1x * dt, d1y * dt, dz)
		sg.comp.type = segKind[i] or 0
		sg.comp.typeIndex = (segKind[i] == 1 and bridgeIdx) or (segKind[i] == 2 and tunnelIdx) or -1
		sg.comp.laneConfigs = tmpl.laneConfigs; sg.comp.roadTemplate = TRACK_TMPL; sg.comp.roadStyle = tmpl.streetStyle
		sg.comp.roadType = api.type.enum.RoadType.TRACK
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
					app.saveUserdata(DIR, "captured_" .. tostring(os.time()) .. "_" .. tostring(cap.seq), cap)
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

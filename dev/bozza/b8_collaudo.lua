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
	pcall(function()
		for k, val in pairs(api.type.enum.TransportVehicleState) do if val == s then name = k end end
	end)
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
	-- percorso tra fermate consecutive (anche dall'ultima alla prima: la linea gira)
	if #modes > 0 then
		for i = 1, #groups do
			local j = i % #groups + 1
			if groups[i] ~= groups[j] and not CC.hasPath(CC.stopNodeId(groups[i]), CC.stopNodeId(groups[j]), modes) then
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
	-- bacino delle fermate
	for i, g in ipairs(groups) do
		local s = CC.groupStation(g)
		if s and #CC.stationCatchables(s) == 0 then
			r.problems[#r.problems + 1] = "la fermata " .. i .. " (" .. (CC.nameOf(g) or "?") .. ") non ha edifici o industrie nel bacino"
			r.suggestions[#r.suggestions + 1] = "spostare la fermata verso il centro o collegarla con una navetta"
		end
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
	for i = 1, math.min(#lines, (a and a.max_lines) or 40) do
		local r = CC.checkLine(lines[i])
		if r.ok then okN = okN + 1 else bad[#bad + 1] = { line_id = r.line_id, name = r.name, problems = r.problems, suggestions = r.suggestions } end
	end
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

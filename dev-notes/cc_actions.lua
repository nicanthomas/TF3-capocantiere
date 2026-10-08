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

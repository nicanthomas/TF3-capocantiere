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
	local count = math.max(1, math.min(20, a.count or 2))
	local lines, vehicles, errs = {}, {}, {}
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
			local okV, v = CC.buyVehicles(depot, model.id, count, li.line)
			for _, x in ipairs(v.vehicles or {}) do vehicles[#vehicles + 1] = x end
			for _, e in ipairs(v.errors or {}) do errs[#errs + 1] = e end
		end
	end
	return { ok = #lines == #patterns and #vehicles > 0 and #errs == 0, line_id = lines[1], line_ids = lines, vehicles = vehicles,
		vehicle = kind, errors = errs }
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

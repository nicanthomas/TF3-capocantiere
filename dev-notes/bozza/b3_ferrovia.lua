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
				local okW, W = CC.buildPassingLoop(w[2] == "a" and ea or eb, opts.waitLen)
				if not okW then return false, "binario d'attesa alla stazione " .. w[1] .. ": " .. tostring(W.error) end
				for _, e in ipairs(W.edges) do builtEdges[#builtEdges + 1] = e end
				if w[2] == "a" then ea = W.exit else eb = W.exit end
				log[#log + 1] = "binario d'attesa fuori dalla stazione " .. w[1] .. (W.warning and (" (" .. W.warning .. ")") or "")
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
	local P1, P2 = CC.posOf(ind), CC.posOf(target)
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

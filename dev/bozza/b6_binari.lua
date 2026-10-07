-- ===================================================================== BOZZA (NON TESTATO) - b6 binari
-- Doppio binario (un binario per senso con segnali a senso unico), diramazioni, binari d'incrocio/attesa,
-- segnali, linee circolari (anello) percorse nei due sensi.
-- DA VERIFICARE in gioco (sonda s8 e prove p12, p13): come si piazza un segnale da script (EdgeObject), il nome del
-- modello del segnale e quale lato/verso corrisponde al senso di marcia.

CC.TRACK_SPACING = CC.TRACK_SPACING or 5          -- distanza tra gli assi dei due binari (m)
CC.SPLIT_LEN = CC.SPLIT_LEN or 120                -- lunghezza della diramazione (scambio) che apre il doppio binario
CC.SIGNAL_EVERY = CC.SIGNAL_EVERY or 700          -- un segnale ogni ... m (blocchi: piu' treni sulla stessa tratta)
CC.SIGNAL_LEFT_MEANS_FORWARD = CC.SIGNAL_LEFT_MEANS_FORWARD or false   -- DA VERIFICARE (sonda s8)
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
function CC.buildSplit(E, L, spacing, side)
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

-- ---------------------------------------------------------------- segnali
-- Modello del segnale: CC.SIGNAL_MODEL (dalla sonda s8) o il primo nome conosciuto che esiste. DA VERIFICARE.
function CC.signalModel()
	if CC.SIGNAL_MODEL then return CC.SIGNAL_MODEL end
	for _, n in ipairs({ "railroad/signal_new_block.mdl", "railroad/signal_block.mdl", "railroad/signal_new_path.mdl", "railroad/signal.mdl" }) do
		local id = -1
		pcall(function() id = api.res.modelRep.find(n) end)
		if id and id >= 0 then return n end
	end
	return nil
end

local function edgeEnds(e)
	local be = CC.comp(e, api.type.ComponentType.BASE_EDGE)
	if not be then return nil end
	return be.position0, be.position1
end

-- Segnali lungo una serie di binari (edges di un tracciato), ogni opts.every m.
-- opts.from = { x, y }: da dove partono i treni (senso di marcia); opts.oneWay: senso unico (doppio binario).
-- Il segnale va con EdgeObject nella proposta (come nel gioco base di TF2). DA VERIFICARE: se il gioco vuole
-- gli oggetti solo insieme a binari nuovi, va spostato dentro la costruzione del binario.
function CC.addSignals(edges, opts)
	opts = opts or {}
	local model = CC.signalModel()
	if not model then return false, { error = "modello del segnale non trovato (sonda s8)" } end
	local every = opts.every or CC.SIGNAL_EVERY
	local from = opts.from or { x = 0, y = 0 }
	local list = {}
	for _, e in ipairs(edges or {}) do
		local p0, p1 = edgeEnds(e)
		if p0 then
			local d0 = (p0.x - from.x) ^ 2 + (p0.y - from.y) ^ 2
			local d1 = (p1.x - from.x) ^ 2 + (p1.y - from.y) ^ 2
			local len = math.sqrt((p1.x - p0.x) ^ 2 + (p1.y - p0.y) ^ 2)
			list[#list + 1] = { e = e, forward = d0 <= d1, len = len, key = math.min(d0, d1) }
		end
	end
	table.sort(list, function(u, v) return u.key < v.key end)
	local objs, acc = {}, every / 2
	local player = api.engine.util.getPlayer()
	for _, it in ipairs(list) do
		acc = acc + it.len
		if acc >= every then
			acc = 0
			local eo
			pcall(function() eo = api.type.SimpleStreetProposal.EdgeObject.new() end)
			eo = eo or {}
			eo.edgeEntity = it.e
			eo.param = 0.5
			eo.oneWay = opts.oneWay == true
			eo.left = (it.forward == CC.SIGNAL_LEFT_MEANS_FORWARD)
			eo.model = model
			eo.playerEntity = player
			objs[#objs + 1] = eo
		end
	end
	if #objs == 0 then return true, { signals = 0 } end
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.edgeObjectsToAdd = objs
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = "segnali: " .. tostring(cmd) } end
	local ok = CC.send(cmd)
	return ok, { signals = ok and #objs or 0, error = (not ok) and "segnali rifiutati" or nil }
end

-- ---------------------------------------------------------------- collegamento di due estremi
-- Come in build_rail_line: forme di curva diverse, deviazione, ripiego dall'alta velocita' allo standard.
function CC.linkTwoEnds(ea, eb, log, label)
	local ok, info
	for _, kf in ipairs({ 0.9, 0.5, 1.4, 0.3 }) do
		ok, info = CC.buildCurvedTrack(ea, eb, 60, false, kf)
		if ok or not info.retry then break end
		log[#log + 1] = label .. ": " .. tostring(info.error) .. ", provo un altro tracciato"
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

-- Doppio binario tra due "gruppi" di estremi: As (2 estremi dalla parte a), Bs (2 dalla parte b).
-- Il binario a destra (rispetto al verso a -> b) e' per i treni a -> b, l'altro per b -> a (al contrario con
-- CC.LEFT_HAND_TRAFFIC). Segnali a senso unico su entrambi.
function CC.linkDouble(As, Bs, log, label, builtEdges)
	local ca = { x = (As[1].x + As[2].x) / 2, y = (As[1].y + As[2].y) / 2 }
	local cb = { x = (Bs[1].x + Bs[2].x) / 2, y = (Bs[1].y + Bs[2].y) / 2 }
	As, Bs = pairByLane(As, Bs, ca.x, ca.y, cb.x, cb.y)
	local warnings = {}
	for k = 1, 2 do
		local ok, info = CC.linkTwoEnds(As[k], Bs[k], log, label .. (k == 1 and " (binario 1)" or " (binario 2)"))
		if not ok then
			local msg = tostring(info.error)
			if info.detail and info.detail.msg then msg = msg .. " (" .. table.concat(info.detail.msg, "; ") .. ")" end
			return false, label .. ": " .. msg
		end
		for _, e in ipairs(info.edges or {}) do builtEdges[#builtEdges + 1] = e end
		-- k = 1: lato destro (chiave piu' bassa rispetto alla normale sinistra) -> treni da a verso b
		local aToB = (k == 1) ~= CC.LEFT_HAND_TRAFFIC
		local okS, S = CC.addSignals(info.edges, { oneWay = true, from = aToB and ca or cb })
		if not okS then warnings[#warnings + 1] = label .. ": " .. tostring(S.error) end
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
		if i == 1 then
			merge.b = false
			local need = a.double_track and 3 or 2
			if plan.tracks < need then plan.tracks = need; plan.layout = CC.stationLayout(plan.tracks, plan.through) end
		end
		local tname = CC.nameOf(t) or ("citta' " .. i)
		local st, info = CC.placeStationSmart(C[i], dx, dy, { prev, nxt }, tname .. " stazione", plan, {
			merge = merge, min_tracks = (i == 1) and (a.double_track and 3 or 2) or nil,
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
			local okA, SA = CC.buildSplit(fromEnd)
			if not okA then return { ok = false, error = label .. ": " .. tostring(SA.error), log = log } end
			for _, e in ipairs(SA.edges) do builtEdges[#builtEdges + 1] = e end
			local Bs
			if j == 1 then
				Bs = { sb.sides.b[1], sb.sides.b[2] }
			else
				local okB, SB = CC.buildSplit(sb.sides.b[1])
				if not okB then return { ok = false, error = label .. ": " .. tostring(SB.error), log = log } end
				for _, e in ipairs(SB.edges) do builtEdges[#builtEdges + 1] = e end
				Bs = { SB.a, SB.b }
			end
			local okD, D = CC.linkDouble({ SA.a, SA.b }, Bs, log, label, builtEdges)
			if not okD then return { ok = false, error = D, log = log } end
			for _, w in ipairs(D.warnings) do warnings[#warnings + 1] = w end
		else
			local okL, info = CC.linkTwoEnds(fromEnd, sb.sides.b[1], log, label)
			if not okL then return { ok = false, error = label .. ": " .. tostring(info.error), log = log } end
			for _, e in ipairs(info.edges or {}) do builtEdges[#builtEdges + 1] = e end
		end
	end
	local depotEnd = stations[1].sides.b[#stations[1].sides.b]
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

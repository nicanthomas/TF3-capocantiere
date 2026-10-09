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

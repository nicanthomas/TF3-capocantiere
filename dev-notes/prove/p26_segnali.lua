-- PROVA 26 (08.10.2026): piazzare SEGNALI da script e capire il verso. Dallo scalo merci della p23 (costruzione
-- 89548) due binari dritti da 300 m; segnale 1 (left = true, oneWay = false) sul primo, segnale 2 (left = false,
-- oneWay = true) sul secondo. Modello copiato dalla partita di terzi: infrastructure/signal/signal_path_c.mdl.
-- Poi si legge com'e' venuto: SIGNAL_LIST.signals[1].type, edgePr[2] (true = verso node0 -> node1), node0/node1.
local CT = api.type.ComponentType
local out = { log = {} }
local con = CC.PROVA_CON or 89548
local ends = CC.railStationEnds(con)
out.nEnds = #ends
local E = ends[1]
if not E then return { error = "estremi dello scalo non trovati" } end
-- verso l'interno della mappa
for _, e in ipairs(ends) do if CC.inMap(e.x + e.dx * 700, e.y + e.dy * 700, 200) then E = e break end end
out.E = { x = E.x, y = E.y, dx = E.dx, dy = E.dy }
local ok1, T1
for _, cand in ipairs(ends) do
	for _, L in ipairs({ 300, 150 }) do
		ok1, T1 = CC.extendTrack(cand, L)
		local R = CC._last or {}
		out.log[#out.log + 1] = { node = cand.node, L = L, ok = ok1, exc = R.exception, err = (not ok1) and R.res and CC.proposalErrors(R.res) or nil }
		if ok1 then E = cand break end
	end
	if ok1 then break end
end
if not ok1 then return out end
local ok2, T2 = CC.extendTrack(T1.endInfo, 300)
if not ok2 then return { error = "binario 2: " .. tostring(T2.error), e1 = T1.edges } end
out.edges1, out.edges2 = T1.edges, T2.edges
local model = "infrastructure/signal/signal_path_c.mdl"
pcall(function() out.modelId = api.res.modelRep.find(model) end)
local function eo(edge, left, oneWay)
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = edge
	o.param = 0.5
	o.oneWay = oneWay
	o.left = left
	o.model = model
	o.playerEntity = api.engine.util.getPlayer()
	return o
end
pcall(function() out.eoFields = tostring(api.type.SimpleStreetProposal.EdgeObject.new()) end)
local prop = api.type.SimpleProposal.new()
prop.streetProposal.edgeObjectsToAdd = { eo(T1.edges[1], true, false), eo(T2.edges[1], false, true) }
local okc, cmd = CC.buildCmd(prop, false)
out.buildCmd = okc and "ok" or tostring(cmd)
if okc then out.sent = CC.send(cmd) end
local function readEdge(e)
	local be = CC.comp(e, CT.BASE_EDGE)
	local r = { edge = e, node0 = be.node0, node1 = be.node1,
		p0 = string.format("%.1f %.1f", be.position0.x, be.position0.y), p1 = string.format("%.1f %.1f", be.position1.x, be.position1.y),
		objects = {} }
	if type(be.objects) == "table" then
		for _, o in ipairs(be.objects) do
			local sl = CC.comp(o[1], CT.SIGNAL_LIST)
			local s1 = sl and sl.signals and sl.signals[1]
			local x = { entity = o[1], tipo = o[2] }
			if s1 then x.type = s1.type; pcall(function() x.dir = tostring(s1.edgePr[2]) end) end
			local mi = CC.comp(o[1], CT.MODEL_INSTANCE_LIST)
			pcall(function() local t = mi.fatInstances[1].transf; x.rot = string.format("%.2f %.2f", t[1], t[2]) end)
			r.objects[#r.objects + 1] = x
		end
	end
	return r
end
out.r1 = readEdge(T1.edges[1])
out.r2 = readEdge(T2.edges[1])
return out

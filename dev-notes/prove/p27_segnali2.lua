-- PROVA 27 (08.10.2026): segnali con il metodo di TF2: il binario esistente si toglie e si rimette uguale con
-- comp.objects = { {id_oggetto, 2} } e l'oggetto in edgeObjectsToAdd (edgeEntity = id negativo del binario nuovo).
-- p26: edgeObjectsToAdd da solo su un binario esistente -> "Unknown exception" nella verifica.
-- Binari della p26: 89602 (node0 89574 lato scalo -> 8250) e 35761 (8250 -> 13476), dritti verso +x.
local CT = api.type.ComponentType
local out = { log = {} }
local model = "infrastructure/signal/signal_path_c.mdl"
local EDGES = CC.PROVA_EDGES or { 89602, 35761 }
local SPEC = { { left = true, oneWay = false }, { left = false, oneWay = true } }
local function mkEO(edgeId, s)
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = edgeId
	o.param = 0.5
	o.oneWay = s.oneWay
	o.left = s.left
	o.model = model
	pcall(function() o.playerEntity = api.engine.util.getPlayer() end)
	return o
end
local function proposal(variant)
	local prop = api.type.SimpleProposal.new()
	local adds, objs, rem = {}, {}, {}
	for i, e in ipairs(EDGES) do
		local be = CC.comp(e, CT.BASE_EDGE)
		local sg = api.type.SegmentAndEntity.new()
		local eid = variant.edgeIds[i]
		sg.entity = eid
		sg.type = 1
		sg.comp = be
		sg.comp.objects = { { variant.objIds[i], 2 } }
		adds[i] = sg
		objs[i] = mkEO(eid, SPEC[i])
		rem[i] = e
	end
	prop.streetProposal.edgesToRemove = rem
	prop.streetProposal.edgesToAdd = adds
	prop.streetProposal.edgeObjectsToAdd = objs
	return prop
end
local VARIANTS = {
	{ name = "edge -1/-2, obj -3/-4", edgeIds = { -1, -2 }, objIds = { -3, -4 } },
	{ name = "edge -1/-2, obj -1/-2", edgeIds = { -1, -2 }, objIds = { -1, -2 } },
	{ name = "edge -3/-4, obj -1/-2", edgeIds = { -3, -4 }, objIds = { -1, -2 } },
}
local done = false
for _, v in ipairs(VARIANTS) do
	local okP, prop = pcall(proposal, v)
	if not okP then
		out.log[#out.log + 1] = { v = v.name, err = "proposta: " .. tostring(prop):sub(1, 200) }
	else
		local okc, cmd = CC.buildCmd(prop, false)
		local item = { v = v.name, buildCmd = okc and "ok" or tostring(cmd):sub(1, 200) }
		if okc then
			local ok, res, ents = CC.send(cmd)
			item.sent = ok
			item.ents = ents
			if ok then done = true end
		end
		out.log[#out.log + 1] = item
	end
	if done then break end
end
-- leggere i binari nuovi (ritrovati con l'octree vicino ai punti medi)
out.read = {}
for _, mid in ipairs({ { 1541.5, -4354.4 }, { 1841.5, -4354.4 } }) do
	for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(mid[1], mid[2]), 5, CT.BASE_EDGE))) do
		local be = CC.comp(e, CT.BASE_EDGE)
		local r = { edge = e, node0 = be.node0, node1 = be.node1, objects = {} }
		if type(be.objects) == "table" then
			for _, o in ipairs(be.objects) do
				local sl = CC.comp(o[1], CT.SIGNAL_LIST)
				local s1 = sl and sl.signals and sl.signals[1]
				local x = { entity = o[1], tipo = o[2] }
				if s1 then x.type = s1.type; pcall(function() x.dir = tostring(s1.edgePr[2]) end) end
				local eo = CC.comp(o[1], CT.EDGE_OBJECT)
				if eo then x.param = eo.param end
				local mi = CC.comp(o[1], CT.MODEL_INSTANCE_LIST)
				pcall(function() local t = mi.fatInstances[1].transf; x.rot = string.format("%.2f %.2f", t[1], t[2]); x.pos = string.format("%.1f %.1f", t[13], t[14]) end)
				r.objects[#r.objects + 1] = x
			end
		end
		out.read[#out.read + 1] = r
	end
end
return out

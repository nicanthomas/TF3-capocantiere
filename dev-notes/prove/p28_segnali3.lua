-- PROVA 28 (08.10.2026): segnali.
-- p27: togliere e rimettere il binario con sg.comp = BASE_EDGE copiato -> comando "ok" ma nessun cambiamento.
-- Qui: (D) binario NUOVO con il segnale nella stessa proposta (come servira' costruendo); (C) binario esistente
-- rifatto con trackSeg (campi espliciti) + oggetto. Prima D (prolunga dal nodo 13476, fine dei binari p26, verso +x).
local CT = api.type.ComponentType
local out = { log = {} }
local model = "infrastructure/signal/signal_path_c.mdl"
local function mkEO(edgeId, left, oneWay)
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = edgeId; o.param = 0.5; o.oneWay = oneWay; o.left = left; o.model = model
	pcall(function() o.playerEntity = api.engine.util.getPlayer() end)
	return o
end
local function try(label, prop)
	local okD, info = CC.dryRun(prop)
	local item = { v = label, dry = okD, info = info }
	if okD then
		local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, false, true)
		item.cmd = okc
		if okc then
			local ok, res, ents = CC.send(cmd)
			item.sent = ok; item.ents = ents
			if not ok and res then item.err = CC.proposalErrors(res) end
		end
	end
	out.log[#out.log + 1] = item
	return item.sent, item.ents
end
-- (D) nuovo binario 13476 -> +200 m con segnale (left=true, oneWay=false)
local E = CC.trackEndInfo(CC.PROVA_NODE or 13476)
out.E = E and { x = E.x, y = E.y, dx = E.dx, dy = E.dy } or "estremo non trovato"
if E then
	for vi, ids in ipairs({ { edge = -2, obj = -3 }, { edge = -2, obj = -1 } }) do
		local L = 200
		local ex, ey = E.x + E.dx * L, E.y + E.dy * L
		local P0, P1 = api.type.Vec3f.new(E.x, E.y, E.z), api.type.Vec3f.new(ex, ey, E.z)
		local T = api.type.Vec3f.new(E.dx * L, E.dy * L, 0)
		local n = api.type.NodeAndEntity.new(); n.entity = -1; n.comp.position = P1
		local sg = trackSeg(ids.edge, E.node, P0, T, -1, P1, T)
		sg.comp.objects = { { ids.obj, 2 } }
		local prop = api.type.SimpleProposal.new()
		prop.streetProposal.nodesToAdd = { n }
		prop.streetProposal.edgesToAdd = { sg }
		prop.streetProposal.edgeObjectsToAdd = { mkEO(ids.edge, true, false) }
		local ok = try("D" .. vi .. " nuovo binario edge " .. ids.edge .. " obj " .. ids.obj, prop)
		if ok then break end
	end
end
-- (C) rifare 35761 con trackSeg + oggetto (left=false, oneWay=true)
local e = CC.PROVA_EDGE or 35761
local be = CC.comp(e, CT.BASE_EDGE)
if be then
	local sg = trackSeg(-1, be.node0, be.position0, be.tangent0, be.node1, be.position1, be.tangent1)
	sg.comp.objects = { { -2, 2 } }
	local prop = api.type.SimpleProposal.new()
	prop.streetProposal.edgesToRemove = { e }
	prop.streetProposal.edgesToAdd = { sg }
	prop.streetProposal.edgeObjectsToAdd = { mkEO(-1, false, true) }
	try("C rifatto 35761", prop)
end
return out

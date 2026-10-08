-- PROVA 36: perche' la diramazione (CC.buildSplitOnce) e' "Costruzione non consentita"? Verifica a secco su:
-- (1) estremo libero del binario di prova (nodo 13476, aperta campagna); (2) estremo 'f' della stazione 89809 (anello).
-- Per ogni caso: messaggi e entita' in collisione (tipo).
local CT = api.type.ComponentType
local out = {}
local function dry(E, L, side)
	L, side = L or CC.SPLIT_LEN, side or 1
	local spacing = CC.TRACK_SPACING
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
	local okP, pd = pcall(api.engine.util.proposal.makeProposalData, prop, nil)
	local r = { z = E.z, hA = CC.heightAt(ax, ay), hB = CC.heightAt(bx, by), segsAtNode = #CC.each(api.engine.system.streetSystem.getNodeSegments(E.node)) }
	if not okP or not pd then r.exc = tostring(pd) return r end
	pcall(function() r.critical = pd.errorState.critical; r.msg = {} for _, m in ipairs(CC.each(pd.errorState.messages)) do r.msg[#r.msg + 1] = tostring(m) end end)
	pcall(function()
		r.coll = {}
		for i, c in ipairs(CC.each(pd.collisionInfo.collisionEntities)) do
			if i > 8 then break end
			local e = c.entity
			local kind = CC.comp(e, CT.CONSTRUCTION) and ("costruzione " .. tostring(CC.comp(e, CT.CONSTRUCTION).fileName))
				or CC.comp(e, CT.BASE_EDGE) and ("binario/strada " .. tostring(CC.comp(e, CT.BASE_EDGE).roadTemplate))
				or CC.comp(e, CT.TOWN_BUILDING) and "edificio" or "altro"
			r.coll[#r.coll + 1] = { e = e, kind = kind }
		end
	end)
	-- solo il ramo dritto
	local p1 = api.type.SimpleProposal.new()
	p1.streetProposal.nodesToAdd = { nA }
	p1.streetProposal.edgesToAdd = { trackSeg(-3, E.node, P0, TA, -1, A, TA) }
	local ok1, pd1 = pcall(api.engine.util.proposal.makeProposalData, p1, nil)
	pcall(function() r.soloDritto = tostring(pd1.errorState.critical); r.msg1 = {} for _, m in ipairs(CC.each(pd1.errorState.messages)) do r.msg1[#r.msg1 + 1] = tostring(m) end end)
	return r
end
local E1 = CC.trackEndInfo(13476)
if E1 then out.campagna = dry(E1) else out.campagna = "estremo 13476 non trovato" end
local ends = CC.railStationEnds(CC.PROVA_CON or 89809)
out.stazioneEstremi = #ends
-- estremi liberi vicino alla stazione: quelli dopo gli scambi
local cand = {}
for _, n in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(CC.posOf(CC.PROVA_CON or 89809).x, CC.posOf(CC.PROVA_CON or 89809).y), 500, CT.BASE_NODE))) do
	local E = CC.trackEndInfo(n)
	if E and not CC.inConstruction(E.edge) then cand[#cand + 1] = E end
end
out.estremiLiberi = #cand
out.stazione = {}
for i = 1, math.min(2, #cand) do out.stazione[i] = dry(cand[i]) end
return out

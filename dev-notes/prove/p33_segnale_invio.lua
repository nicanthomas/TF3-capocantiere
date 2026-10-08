-- PROVA 33 (lato interfaccia, INVIO): come la mod Automatic Signal Spacing, senza makeProposalData.
-- Segnale normale (left = true) a meta' del binario CC.PROVA_EDGE (35761).
local CT = api.type.ComponentType
local out = {}
local player = api.engine.util.getPlayer()
local e = CC.PROVA_EDGE or 35761
local p = api.type.SimpleProposal.new()
local be = api.engine.getComponent(e, CT.BASE_EDGE)
local objs = {}
for _, o in ipairs(be.objects or {}) do objs[#objs + 1] = { o[1], o[2] } end
local sg = api.type.SegmentAndEntity.new()
sg.entity = -1; sg.type = 1; sg.comp = be
local po = api.engine.getComponent(e, CT.PLAYER_OWNED)
if po then sg.playerOwned = po end
objs[#objs + 1] = { -400000000, api.type.enum.EdgeObjectType.SIGNAL }
sg.comp.objects = objs
local o = api.type.SimpleStreetProposal.EdgeObject.new()
o.edgeEntity = -1; o.param = 0.5; o.oneWay = false; o.left = true
o.model = "::/infrastructure/signal/signal_path_c.con"; o.playerEntity = player
p.streetProposal.edgesToRemove = { e }
p.streetProposal.edgesToAdd = { sg }
p.streetProposal.edgeObjectsToAdd = { o }
local ctx = api.type.Context.new(); ctx.player = player
local okC, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, ctx, false, true)
out.cmd = okC and "ok" or tostring(cmd):sub(1, 200)
if okC then
	local okS, err = pcall(api.cmd.sendCommand, cmd, function(res, success) end)
	out.send = okS and "inviato" or tostring(err):sub(1, 200)
end
return out

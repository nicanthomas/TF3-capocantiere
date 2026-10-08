-- PROVA 34 (lato simulazione): segnale A SENSO UNICO (oneWay = true, left = false) sul binario CC.PROVA_EDGE (89599,
-- che ha gia' il segnale a mano 89544), come p33 ma dal lato simulazione e SENZA verifica a secco (makeProposalData
-- lancia "Unknown exception" con gli oggetti dei binari).
local CT = api.type.ComponentType
local out = {}
local player = api.engine.util.getPlayer()
local e = CC.PROVA_EDGE or 89599
local p = api.type.SimpleProposal.new()
local be = CC.comp(e, CT.BASE_EDGE)
local objs = {}
for _, o in ipairs(be.objects or {}) do objs[#objs + 1] = { o[1], o[2] } end
local sg = api.type.SegmentAndEntity.new()
sg.entity = -1; sg.type = 1; sg.comp = be
local po = CC.comp(e, CT.PLAYER_OWNED)
if po then sg.playerOwned = po end
objs[#objs + 1] = { -400000000, api.type.enum.EdgeObjectType.SIGNAL }
sg.comp.objects = objs
local o = api.type.SimpleStreetProposal.EdgeObject.new()
o.edgeEntity = -1; o.param = 0.5; o.oneWay = true; o.left = false
o.model = "::/infrastructure/signal/signal_path_c.con"; o.playerEntity = player
p.streetProposal.edgesToRemove = { e }
p.streetProposal.edgesToAdd = { sg }
p.streetProposal.edgeObjectsToAdd = { o }
local ctx = api.type.Context.new(); ctx.player = player
local okC, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, p, ctx, false, true)
out.cmd = okC and "ok" or tostring(cmd):sub(1, 200)
if okC then
	local ok, res, ents = CC.send(cmd)
	out.sent = ok; out.ents = ents
end
return out

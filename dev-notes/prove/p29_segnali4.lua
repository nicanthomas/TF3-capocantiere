-- PROVA 29 (08.10.2026): segnali come la mod "Automatic Signal Spacing" (TF3): binario rifatto (edgesToRemove +
-- SegmentAndEntity con comp = BASE_EDGE copiato, playerOwned), oggetto segnaposto -400000000 in comp.objects,
-- EdgeObject con model = COSTRUZIONE "infrastructure/signal/signal_path_c.con" (non .mdl), Context con il giocatore.
local CT = api.type.ComponentType
local out = {}
local CON = "infrastructure/signal/signal_path_c.con"
local EDGES = CC.PROVA_EDGES or { 89602, 35761 }
local SPEC = { { left = true, oneWay = false }, { left = false, oneWay = true } }
local player = api.engine.util.getPlayer()
local prop = api.type.SimpleProposal.new()
local rem, adds, objs = {}, {}, {}
for i, e in ipairs(EDGES) do
	local be = CC.comp(e, CT.BASE_EDGE)
	local segObjs = {}
	for _, o in ipairs(be.objects or {}) do segObjs[#segObjs + 1] = { o[1], o[2] } end
	local sg = api.type.SegmentAndEntity.new()
	sg.entity = -i
	sg.type = 1
	sg.comp = be
	local po = CC.comp(e, CT.PLAYER_OWNED)
	if po then sg.playerOwned = po end
	segObjs[#segObjs + 1] = { -400000000 - i, api.type.enum.EdgeObjectType.SIGNAL }
	sg.comp.objects = segObjs
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = -i; o.param = 0.5; o.oneWay = SPEC[i].oneWay; o.left = SPEC[i].left; o.model = CON; o.playerEntity = player
	rem[#rem + 1] = e; adds[#adds + 1] = sg; objs[#objs + 1] = o
end
prop.streetProposal.edgesToRemove = rem
prop.streetProposal.edgesToAdd = adds
prop.streetProposal.edgeObjectsToAdd = objs
local okD, info = CC.dryRun(prop)
out.dry = okD; out.info = info
local ctx = api.type.Context.new(); ctx.player = player
local okc, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, ctx, false, true)
out.cmd = okc and "ok" or tostring(cmd)
if okc then
	local ok, res, ents = CC.send(cmd)
	out.sent = ok; out.ents = ents
	if not ok and res then out.err = CC.proposalErrors(res) end
end
return out

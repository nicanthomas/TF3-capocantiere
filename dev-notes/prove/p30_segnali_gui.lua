-- PROVA 30 (lato interfaccia, come la mod Automatic Signal Spacing): segnale sul binario 89602 (e 35761).
local CT = api.type.ComponentType
local out = { steps = {} }
local CON = "infrastructure/signal/signal_path_c.con"
local player = api.engine.util.getPlayer()
local function build(withObj, edges, spec)
	local prop = api.type.SimpleProposal.new()
	local rem, adds, objs = {}, {}, {}
	for i, e in ipairs(edges) do
		local be = api.engine.getComponent(e, CT.BASE_EDGE)
		local segObjs = {}
		for _, o in ipairs(be.objects or {}) do segObjs[#segObjs + 1] = { o[1], o[2] } end
		local sg = api.type.SegmentAndEntity.new()
		sg.entity = -i
		sg.type = 1
		sg.comp = be
		local po = api.engine.getComponent(e, CT.PLAYER_OWNED)
		if po then sg.playerOwned = po end
		if withObj then
			segObjs[#segObjs + 1] = { -400000000 - i, api.type.enum.EdgeObjectType.SIGNAL }
			local o = api.type.SimpleStreetProposal.EdgeObject.new()
			o.edgeEntity = -i; o.param = 0.5; o.oneWay = spec[i].oneWay; o.left = spec[i].left; o.model = CON; o.playerEntity = player
			objs[#objs + 1] = o
		end
		sg.comp.objects = segObjs
		rem[#rem + 1] = e; adds[#adds + 1] = sg
	end
	prop.streetProposal.edgesToRemove = rem
	prop.streetProposal.edgesToAdd = adds
	if withObj then prop.streetProposal.edgeObjectsToAdd = objs end
	return prop
end
local spec = { { left = true, oneWay = false }, { left = false, oneWay = true } }
for _, case in ipairs({ { "solo binario", false }, { "con segnali", true } }) do
	local st = { case = case[1] }
	local okB, prop = pcall(build, case[2], { 89602, 35761 }, spec)
	st.build = okB and "ok" or tostring(prop):sub(1, 150)
	if okB then
		local okP, pd = pcall(api.engine.util.proposal.makeProposalData, prop, nil)
		st.proposalData = okP and "ok" or tostring(pd):sub(1, 150)
		if okP then pcall(function() st.critical = pd.errorState.critical; st.msgs = {} for _, m in ipairs(CC.each(pd.errorState.messages)) do st.msgs[#st.msgs + 1] = tostring(m) end end) end
		if case[2] then
			local ctx = api.type.Context.new(); ctx.player = player
			local okC, cmd = pcall(api.cmd.makeWorldBuildProposalCmd, prop, ctx, false, true)
			st.cmd = okC and "ok" or tostring(cmd):sub(1, 150)
			if okC then
				local okS, e2 = pcall(api.cmd.sendCommand, cmd, function(res, success) end)
				st.sent = okS and "inviato" or tostring(e2):sub(1, 150)
			end
		end
	end
	out.steps[#out.steps + 1] = st
end
return out

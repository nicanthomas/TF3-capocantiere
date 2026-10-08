-- PROVA 31 (lato interfaccia, sola verifica a secco): quale combinazione di EdgeObject accetta il gioco.
local CT = api.type.ComponentType
local out = {}
local player = api.engine.util.getPlayer()
local e = 89602
local function prop(model, objId, setPlayer, fields)
	local p = api.type.SimpleProposal.new()
	local be = api.engine.getComponent(e, CT.BASE_EDGE)
	local sg = api.type.SegmentAndEntity.new()
	sg.entity = -1; sg.type = 1; sg.comp = be
	local po = api.engine.getComponent(e, CT.PLAYER_OWNED)
	if po then sg.playerOwned = po end
	sg.comp.objects = { { objId, 2 } }
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = -1; o.param = 0.5
	if fields then o.oneWay = false; o.left = true end
	o.model = model
	if setPlayer then o.playerEntity = player end
	p.streetProposal.edgesToRemove = { e }
	p.streetProposal.edgesToAdd = { sg }
	p.streetProposal.edgeObjectsToAdd = { o }
	return p
end
pcall(function() out.eoNew = tostring(api.type.SimpleStreetProposal.EdgeObject.new()) end)
pcall(function()
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	out.defaults = { edgeEntity = tostring(o.edgeEntity), param = tostring(o.param), left = tostring(o.left), oneWay = tostring(o.oneWay), model = tostring(o.model), playerEntity = tostring(o.playerEntity) }
end)
local CON = "infrastructure/signal/signal_path_c.con"
for _, m in ipairs({ CON, "::/" .. CON, "infrastructure/signal/signal_path_c.mdl" }) do
	for _, oid in ipairs({ -400000001, -2, -1 }) do
		for _, sp in ipairs({ true, false }) do
			local key = m:sub(-25) .. " obj " .. oid .. (sp and " pl" or "")
			local okB, p = pcall(prop, m, oid, sp, true)
			if not okB then out[key] = "build: " .. tostring(p):sub(1, 60)
			else
				local okP, pd = pcall(api.engine.util.proposal.makeProposalData, p, nil)
				if okP and pd == nil then out[key] = "NIL"
				elseif okP then
					local ms = {}
					pcall(function() for _, x in ipairs(CC.each(pd.errorState.messages)) do ms[#ms + 1] = tostring(x) end end)
					local crit = "?"; pcall(function() crit = tostring(pd.errorState.critical) end)
					out[key] = "OK " .. crit .. " " .. table.concat(ms, ";")
				else out[key] = "EXC" end
			end
		end
	end
end
return out

-- PROVA 32 (lato interfaccia, verifica a secco): EdgeObject del segnale con model = "::/infrastructure/signal/signal_path_c.con"
-- (come EDGE_OBJECT.edgeObjectConstruction di un segnale messo a mano) e params come quelli del segnale a mano.
local CT = api.type.ComponentType
local out = {}
local player = api.engine.util.getPlayer()
local e = CC.PROVA_EDGE or 35761
local function prop(model, params, objId)
	local p = api.type.SimpleProposal.new()
	local be = api.engine.getComponent(e, CT.BASE_EDGE)
	local sg = api.type.SegmentAndEntity.new()
	sg.entity = -1; sg.type = 1; sg.comp = be
	local po = api.engine.getComponent(e, CT.PLAYER_OWNED)
	if po then sg.playerOwned = po end
	sg.comp.objects = { { objId, 2 } }
	local o = api.type.SimpleStreetProposal.EdgeObject.new()
	o.edgeEntity = -1; o.param = 0.5; o.oneWay = false; o.left = true; o.model = model; o.playerEntity = player
	if params then o.params = params end
	p.streetProposal.edgesToRemove = { e }
	p.streetProposal.edgesToAdd = { sg }
	p.streetProposal.edgeObjectsToAdd = { o }
	return p
end
local CON = "::/infrastructure/signal/signal_path_c.con"
local cases = {
	{ "A con, no params", CON, nil, -400000001 },
	{ "B con, year+seed", CON, { year = 2020, seed = 0 }, -400000001 },
	{ "C con, year+seed+oneWay2", CON, { year = 2020, seed = 0, oneWay = 2 }, -400000001 },
	{ "D con, params, obj -1", CON, { year = 2020, seed = 0, oneWay = 2 }, -1 },
	{ "E senza ::/, params", "infrastructure/signal/signal_path_c.con", { year = 2020, seed = 0, oneWay = 2 }, -400000001 },
}
for _, c in ipairs(cases) do
	local okB, p = pcall(prop, c[2], c[3], c[4])
	if not okB then out[c[1]] = "build: " .. tostring(p):sub(1, 80)
	else
		local okP, pd = pcall(api.engine.util.proposal.makeProposalData, p, nil)
		if not okP then out[c[1]] = "EXC"
		elseif pd == nil then out[c[1]] = "NIL"
		else
			local crit, ms = "?", {}
			pcall(function() crit = tostring(pd.errorState.critical); for _, x in ipairs(CC.each(pd.errorState.messages)) do ms[#ms + 1] = tostring(x) end end)
			out[c[1]] = "OK crit=" .. crit .. " " .. table.concat(ms, ";")
		end
	end
end
return out

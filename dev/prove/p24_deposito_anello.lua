-- PROVA 24: deposito ferroviario per le stazioni dell'anello (estremi liberi o binario d'accesso), una per volta.
local out = {}
for gg in pairs(CC.playerGroups()) do
	if CC.groupCarriers(gg).rail and not out.ok then
		local r = SIM_ACTIONS.build_depot({ kind = "rail", station_id = gg })
		out[#out + 1] = { gg, CC.nameOf(gg), r.ok, r.error, r.depot_id }
		if r.ok then out.ok = true end
	end
end
return out

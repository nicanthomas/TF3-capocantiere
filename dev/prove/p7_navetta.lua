-- PROVA 7: navetta bus tra una stazione ferroviaria del giocatore e il centro della sua citta'.
local CT = api.type.ComponentType
local target
for g in pairs(CC.playerGroups()) do
	local ok = false
	pcall(function()
		local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
		for _, c in ipairs(CC.each(car[1])) do if c == api.type.enum.Carrier.RAIL then ok = true end end
	end)
	if ok then target = g; break end
end
if not target then return "nessuna stazione ferroviaria del giocatore" end
return SIM_ACTIONS.connect_station_to_town({ station_id = target, num_vehicles = 1 })

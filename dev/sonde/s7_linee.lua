-- SONDA 7 (sola lettura): come sono fatte le linee e i veicoli esistenti (per aggiungere/sostituire veicoli)
-- e cosa "vede" ogni stazione nel suo bacino (catchmentAreaSystem.getStationCatchables).
local CT = api.type.ComponentType
local out = {}
local lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))
for i = 1, math.min(6, #lines) do
	local L = lines[i]
	local r = { id = L, name = CC.nameOf(L), stops = {}, vehicles = {} }
	local lc = CC.comp(L, CT.LINE)
	pcall(function()
		for _, s in ipairs(CC.each(lc.stops)) do
			local info = { group = s.stationGroup }
			pcall(function()
				local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
				local st = CC.each(sg.stations)[1]
				info.catchables = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(st, true))
			end)
			r.stops[#r.stops + 1] = info
		end
	end)
	pcall(function()
		for _, v in ipairs(CC.each(api.engine.system.transportVehicleSystem.getLineVehicles(L))) do
			local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
			local models = {}
			pcall(function() for _, p in ipairs(CC.each(tv.transportVehicleConfig.vehicles)) do models[#models + 1] = api.res.modelRep.getName(p.part.modelId) end end)
			r.vehicles[#r.vehicles + 1] = { id = v, models = models, state = tostring(tv.state) }
		end
	end)
	out[#out + 1] = r
end
return out

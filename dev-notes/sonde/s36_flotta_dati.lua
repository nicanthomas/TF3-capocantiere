-- SONDA 36 (sola lettura, punto 4b): i valori delle funzioni trovate da s23 per l'analisi della flotta (09.10.2026).
-- CC.PROBE_LINE = id linea.
local CT = api.type.ComponentType
local L = CC.PROBE_LINE
local function dump(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 3 then return tostring(v) end
	local r, n = {}, 0
	pcall(function() for k, x in pairs(v) do n = n + 1; if n <= 25 then r[tostring(k)] = dump(x, depth + 1) end end end)
	if n == 0 then
		pcall(function() local s = v:size(); r.size = s; for i = 1, math.min(s, 10) do r["at" .. i] = dump(v:at(i), depth + 1) end end)
		for _, f in ipairs({ "x", "y", "entity", "line", "stopIndex", "state", "capacity", "count", "load", "loadedCount",
			"waiting", "usage", "time", "lastLineStopDepartureTime", "lineStopDepartures", "arrivalTime", "departureTime",
			"doorsTime", "transportVehicleConfig", "userData", "daysInDepot", "timeUntilLeave", "sectionTimes",
			"timeSpentInStation", "stationIndex", "speed" }) do
			pcall(function() local x = v[f]; if x ~= nil then r[f] = dump(x, depth + 1) end end)
		end
		if next(r) == nil then return tostring(v) end
	end
	return r
end
local out = { line = L }
local U = api.engine.util.line
out.maxFreq = dump(U.getMaxFrequency(L))
out.through = dump(U.calcLineStationThroughput(L))
pcall(function() out.capUsage = dump(U.getLineCapacityUsages(L)) end)
pcall(function() out.problems = dump(U.getLineProblems(L)) end)
pcall(function() out.issues = dump(U.getLineIssues(L)) end)
local TVS = api.engine.system.transportVehicleSystem
pcall(function() out.cargoInfo = dump(TVS.getLineCargoInfo(L)) end)
pcall(function() out.stopVehicles = dump(TVS.getLineStopVehicles(L)) end)
local vs = CC.lineVehicles(L)
out.vehicles = #vs
for i = 1, math.min(2, #vs) do
	local v = vs[i]
	local r = {}
	pcall(function() r.info = dump(TVS.getInfo(v)) end)
	pcall(function() r.tv = dump(CC.comp(v, CT.TRANSPORT_VEHICLE)) end)
	pcall(function() r.cap = dump(api.engine.util.vehicle.getVehicleCapacities(v)) end)
	pcall(function() r.speed = api.engine.util.vehicle.getSpeed(v) end)
	out["v" .. i] = r
end
pcall(function() out.lineComp = dump(CC.comp(L, CT.LINE)) end)
pcall(function() out.gameTime = api.engine.getComponent(0, CT.GAME_TIME) and dump(api.engine.getComponent(0, CT.GAME_TIME)) end)
return out

-- SONDA 1 (sola lettura): nomi delle funzioni disponibili nell'API (comandi, util, system, componenti, enum).
-- Serve per: salvataggio automatico, modifica/cancellazione linee, cose nuove della build.
local out = {}
local function keys(t, filter)
	local r = {}
	pcall(function() for k in pairs(t) do local s = tostring(k); if not filter or s:lower():find(filter) then r[#r + 1] = s end end end)
	table.sort(r)
	return r
end
out.cmd = keys(api.cmd)
out.util = keys(api.engine.util)
out.system = keys(api.engine.system)
out.res = keys(api.res)
out.componentTypes = keys(api.type.ComponentType)
out.transportModes = keys(api.type.enum.TransportMode)
out.carriers = keys(api.type.enum.Carrier)
-- sotto-moduli piu' usati
for _, n in ipairs({ "line", "station", "town", "vehicle", "proposal", "construction", "stock" }) do
	pcall(function() out["util_" .. n] = keys(api.engine.util[n]) end)
end
for _, n in ipairs({ "lineSystem", "catchmentAreaSystem", "transportVehicleSystem", "stationGroupSystem", "streetConnectorSystem" }) do
	pcall(function() out["sys_" .. n] = keys(api.engine.system[n]) end)
end
pcall(function() out.speed = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup end)
pcall(function() out.year = CC.year() end)
return out

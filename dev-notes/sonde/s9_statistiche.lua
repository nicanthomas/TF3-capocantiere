-- SONDA 9 (sola lettura): dove sono le statistiche (passeggeri/merci trasportati, frequenza) e lo stato/posizione dei
-- veicoli, per il collaudo (b8). Serve almeno una linea con veicoli che girano da qualche minuto.
local CT = api.type.ComponentType
local out = { lines = {}, vehicles = {}, enums = {}, utilLine = {} }
local function try(label, f, dst)
	local ok, v = pcall(f)
	dst[label] = ok and (type(v) == "userdata" and tostring(v) or v) or ("ERR " .. tostring(v):sub(1, 80))
end
local lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))
for i = 1, math.min(3, #lines) do
	local L = lines[i]
	local r = { id = L, name = CC.nameOf(L) }
	local lc = CC.comp(L, CT.LINE)
	for _, f in ipairs({ "itemsTransported", "transported", "frequency", "rate", "waitingTime", "stops", "vehicleInfo" }) do
		try("LINE." .. f, function() return lc[f] end, r)
	end
	try("util.line.getFrequency", function() return api.engine.util.line.getFrequency(L) end, r)
	try("util.line.getRate", function() return api.engine.util.line.getRate(L) end, r)
	try("game.interface.getEntity.itemsTransported", function() return game.interface.getEntity(L).itemsTransported end, r)
	try("game.interface.getEntity.frequency", function() return game.interface.getEntity(L).frequency end, r)
	try("lineSystem.getLineStops", function() return #CC.each(api.engine.system.lineSystem.getLineStops(L)) end, r)
	for name, id in pairs(CT) do
		local okC, c = pcall(api.engine.getComponent, L, id)
		if okC and c then r["component_" .. name] = true end
	end
	out.lines[#out.lines + 1] = r
	local vs = CC.lineVehicles(L)
	for k = 1, math.min(2, #vs) do
		local v = vs[k]
		local vr = { id = v }
		local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
		for _, f in ipairs({ "state", "line", "stopIndex", "lineStopIndex", "doorsOpen", "timeUntilLoad", "carrierType" }) do
			try("TV." .. f, function() return tv[f] end, vr)
		end
		try("posOf", function() local p = CC.posOf(v); return p and (math.floor(p.x) .. "," .. math.floor(p.y)) end, vr)
		try("MOVE_PATH.dyn.pathPos", function() local d = CC.comp(v, CT.MOVE_PATH).dyn; return d.pathPos.x .. "," .. d.pathPos.y end, vr)
		for name, id in pairs(CT) do
			local okC, c = pcall(api.engine.getComponent, v, id)
			if okC and c then vr["component_" .. name] = true end
		end
		out.vehicles[#out.vehicles + 1] = vr
	end
end
pcall(function() for k, val in pairs(api.type.enum.TransportVehicleState) do out.enums[k] = val end end)
pcall(function() for k in pairs(api.engine.util.line) do out.utilLine[#out.utilLine + 1] = tostring(k) end end)
pcall(function() out.gameTime = CC.comp(api.engine.util.getWorld(), CT.GAME_TIME).gameTime end)
return out

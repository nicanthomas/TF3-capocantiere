-- SONDA 11 (sola lettura): data e tempo di gioco, build del gioco, salvataggio automatico.
-- Serve per: collaudo dopo 1-2 mesi (middleware/collaudo.py: GAME_TIME_PER_MONTH), avviso cambio build,
-- salvataggio prima delle azioni grandi. Eseguirla due volte a qualche minuto di distanza (gioco in corsa).
local CT = api.type.ComponentType
local out = {}
pcall(function() out.gameTime = CC.comp(api.engine.util.getWorld(), CT.GAME_TIME).gameTime end)
pcall(function() out.year = api.engine.util.getYear() end)
pcall(function() local d = game.interface.getGameTime(); out.interfaceTime = { date = d.date, time = d.time } end)
pcall(function() out.buildVersion = api.util.getBuildVersion() end)
pcall(function() out.gameConfig = tostring(game.config) end)
local function keys(t, filter)
	local r = {}
	pcall(function() for k in pairs(t) do local s = tostring(k); if not filter or s:lower():find(filter) then r[#r + 1] = s end end end)
	table.sort(r)
	return r
end
out.cmdSave = keys(api.cmd, "save")
out.cmdGame = keys(api.cmd, "game")
out.util = keys(api.util or {})
out.engineUtilDate = keys(api.engine.util, "date")
out.engineUtilTime = keys(api.engine.util, "time")
pcall(function() out.interface = keys(game.interface) end)
return out

-- SONDA 35 (sola lettura, punto 1b): stazioni INTEGRATE delle industrie nella partita di prova. Per ogni industria:
-- stazioni non del giocatore entro 250 m che appartengono alla costruzione dell'industria (file in industries/),
-- gruppo, mezzi serviti (carriers), terminali, nodo di fermata, merci in uscita/entrata.
local CT = api.type.ComponentType
local out = {}
for _, ind in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.INDUSTRY))) do
	local p = CC.posOf(ind)
	local r = { id = ind, name = CC.nameOf(ind), st = {} }
	if p then
		for _, st in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 250, CT.STATION))) do
			local okC, con = pcall(api.engine.system.streetConnectorSystem.getConstructionEntityForStation, st)
			local c = okC and con and con >= 0 and CC.comp(con, CT.CONSTRUCTION)
			local f = c and tostring(c.fileName) or "?"
			if f:find("industries/", 1, true) then
				local x = { station = st, construction = con, file = f:gsub("^.*industries/", "") }
				pcall(function() x.group = api.engine.system.stationGroupSystem.getStationGroup(st) end)
				pcall(function() x.carriers = CC.groupCarriers(x.group) end)
				pcall(function() x.terminals = #CC.each(CC.comp(st, CT.STATION).terminals) end)
				pcall(function() x.cargo = CC.comp(st, CT.STATION).cargo end)
				pcall(function() x.stopNode = CC.stopNodeId(x.group) end)
				pcall(function() x.player = CC.comp(con, CT.PLAYER_OWNED) ~= nil end)
				r.st[#r.st + 1] = x
			end
		end
	end
	out[#out + 1] = r
end
return out

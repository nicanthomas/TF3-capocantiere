-- SONDA 25 (sola lettura): le industrie di TF3 hanno una stazione integrata utilizzabile in una linea?
-- Per UN'industria per tipo (fino a 32 tipi, asciutte; accesso una sola volta alla partita di terzi): stazioni dentro la costruzione dell'industria, stazioni/gruppi non del
-- giocatore entro 400 m, mezzi serviti (carriers), terminali, bacino; campi della costruzione e dell'industria.
local CT = api.type.ComponentType
local out = { industrie = {}, tipi = {} }
local function keys(t, max)
	local r = {}
	pcall(function() for k, v in pairs(t) do r[#r + 1] = tostring(k) .. ":" .. type(v); if #r >= (max or 60) then break end end end)
	table.sort(r)
	return r
end
local function stationInfo(st)
	local r = { station = st }
	local sc = CC.comp(st, CT.STATION)
	if not sc then return r end
	r.fields = keys(sc)
	pcall(function() r.cargo = sc.cargo end)
	pcall(function() r.terminals = #CC.each(sc.terminals) end)
	pcall(function() r.group = api.engine.system.stationGroupSystem.getStationGroup(st) end)
	pcall(function() r.carriers = CC.groupCarriers and CC.groupCarriers(r.group) end)
	pcall(function() r.catchables = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(st, true)) end)
	pcall(function()
		local con = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(st)
		r.construction = con
		r.constructionFile = tostring(CC.comp(con, CT.CONSTRUCTION).fileName)
		r.playerOwned = CC.comp(con, CT.PLAYER_OWNED) ~= nil
	end)
	return r
end
local n, typeSeen = 0, {}
local function indType(ind)
	local f = "?"
	pcall(function()
		local c = CC.comp(ind, CT.CONSTRUCTION)
		if not c then c = CC.comp(api.engine.system.streetConnectorSystem.getConstructionEntityForSimBuilding(ind), CT.CONSTRUCTION) end
		f = tostring(c.fileName)
	end)
	return f
end
for _, ind in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.INDUSTRY))) do
	if n >= 32 then break end
	local p = CC.posOf(ind)
	local ty = indType(ind)
	if ty == "?" then ty = "?" .. tostring(ind) end
	if p and not typeSeen[ty] and not CC.onWater(p.x, p.y) then
		typeSeen[ty] = true
		n = n + 1
		local r = { id = ind, name = CC.nameOf(ind), stations = {}, near = {} }
		r.industry_fields = keys(CC.comp(ind, CT.INDUSTRY))
		-- costruzione dell'industria e sue stazioni
		pcall(function()
			local con = ind
			local c = CC.comp(con, CT.CONSTRUCTION)
			if not c then
				con = api.engine.system.streetConnectorSystem.getConstructionEntityForSimBuilding(ind)
				c = CC.comp(con, CT.CONSTRUCTION)
			end
			r.construction = con
			r.file = c and tostring(c.fileName)
			r.construction_fields = keys(c)
			for _, st in ipairs(CC.each(c.stations)) do r.stations[#r.stations + 1] = stationInfo(st) end
			r.depots = #CC.each(c.depots)
		end)
		-- stazioni vicine non costruite dal giocatore
		pcall(function()
			for _, st in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 400, CT.STATION))) do
				if #r.near < 4 then r.near[#r.near + 1] = stationInfo(st) end
			end
		end)
		out.industrie[#out.industrie + 1] = r
	end
end
pcall(function() out.streetConnectorSystem = keys(api.engine.system.streetConnectorSystem, 40) end)
return out

-- SONDA 20: confini della mappa. Funzioni del terreno e ricerca del bordo lungo i 4 assi.
local out = { fn = {} }
local t = api.engine.terrain or (api.engine.util and api.engine.util.terrain)
pcall(function() for k, v in pairs(t) do out.fn[#out.fn + 1] = tostring(k) .. ":" .. type(v) end end)
pcall(function()
	local mt = getmetatable(t)
	if mt and mt.__index then for k, v in pairs(mt.__index) do out.fn[#out.fn + 1] = "mt." .. tostring(k) end end
end)
-- tentativi diretti
local tries = { "getTerrainSize", "getSize", "getBounds", "getMapSize", "getExtent" }
out.direct = {}
for _, n in ipairs(tries) do
	pcall(function()
		if t[n] then
			local ok, r = pcall(t[n])
			out.direct[n] = ok and tostring(r) or ("ERR " .. tostring(r))
		end
	end)
end
pcall(function()
	local w = api.engine.util.getWorld()
	out.world = tostring(w)
	local ok, c = pcall(api.engine.getComponent, w, api.type.ComponentType.TERRAIN)
	out.terrainComp = ok and tostring(c) or ("ERR " .. tostring(c))
end)
pcall(function() out.mapSize = tostring(api.engine.util.getMapSize and api.engine.util.getMapSize()) end)
-- campioni lungo gli assi
out.samples = {}
for _, d in ipairs({ { 1, 0, "+x" }, { -1, 0, "-x" }, { 0, 1, "+y" }, { 0, -1, "-y" } }) do
	local row = {}
	for _, r in ipairs({ 4000, 6000, 7000, 7500, 8000, 8250, 8500, 9000, 10000, 12000, 16000, 20000 }) do
		local ok, h = pcall(t.getHeightAt, api.type.Vec2f.new(d[1] * r, d[2] * r))
		row[#row + 1] = r .. "=" .. (ok and string.format("%.1f", h) or "ERR")
	end
	out.samples[d[3]] = table.concat(row, " ")
end
return out

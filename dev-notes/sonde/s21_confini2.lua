-- SONDA 21: CC.mapBox / CC.inMap (b1) e forma di getBoundingBox.
local t = api.engine.terrain or (api.engine.util and api.engine.util.terrain)
local out = {}
pcall(function() local b = t.getBoundingBox(); out.raw = tostring(b); out.min = tostring(b.min); out.max = tostring(b.max)
	pcall(function() out.minx = b.min.x; out.maxx = b.max.x; out.miny = b.min.y; out.maxy = b.max.y end) end)
pcall(function() out.valid0 = tostring(t.isValidCoordinate(api.type.Vec2f.new(0, 0))); out.valid9k = tostring(t.isValidCoordinate(api.type.Vec2f.new(9000, 0))) end)
CC._mapBox = nil
out.box = CC.mapBox()
out.tests = {}
for _, p in ipairs({ { 0, 0 }, { 7800, 0 }, { 8100, 0 }, { 0, -8100 }, { 9000, 9000 } }) do
	out.tests[#out.tests + 1] = p[1] .. "," .. p[2] .. "=" .. tostring(CC.inMap(p[1], p[2]))
end
return out

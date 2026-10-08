-- DIAGNOSI (sola lettura): dove andrebbero le prove p10/p19 (citta' scelte, gruppi ferroviari) e cosa c'e' vicino
-- alla fattoria di Centauro (punto dei crash).
local out = { towns = {}, railGroups = {}, near = {} }
for i, t in ipairs(T.towns()) do if i <= 3 then out.towns[i] = { t.name, t.id, math.floor(t.x), math.floor(t.y) } end end
for g in pairs(CC.playerGroups()) do
	local c = CC.groupCarriers(g)
	local p = CC.posOf(g)
	out.railGroups[#out.railGroups + 1] = { g, CC.nameOf(g), c.rail and "rail" or "", c.road and "road" or "", p and math.floor(p.x), p and math.floor(p.y) }
end
local pair = T.townPair(2000, 6000, 3500)
out.heliPair = pair and { pair[1].name, pair[2].name, pair.d }
for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(4400, 5300), 400, api.type.ComponentType.CONSTRUCTION))) do
	local c = CC.comp(e, api.type.ComponentType.CONSTRUCTION)
	out.near[#out.near + 1] = { e, c and tostring(c.fileName), CC.nameOf(e) }
end
return out

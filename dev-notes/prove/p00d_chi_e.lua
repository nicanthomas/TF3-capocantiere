-- DIAGNOSI: che cosa sono le entita' con cui collide il deposito (85280, 85281)?
local CT = api.type.ComponentType
local out = {}
for _, e in ipairs({ 85280, 85281 }) do
	local r = { id = e, exists = api.engine.entityExists(e), name = CC.nameOf(e), comps = {} }
	for _, n in ipairs({ "CONSTRUCTION", "BASE_EDGE", "BASE_EDGE_STREET", "BASE_NODE", "TOWN_BUILDING", "FIELD", "INDUSTRY", "STATION", "VEHICLE_DEPOT", "MODEL_INSTANCE_LIST" }) do
		local ok, c = pcall(api.engine.getComponent, e, CT[n])
		if ok and c then r.comps[#r.comps + 1] = n end
	end
	local c = CC.comp(e, CT.CONSTRUCTION)
	if c then r.file = tostring(c.fileName) end
	local be = CC.comp(e, CT.BASE_EDGE)
	if be then r.tmpl = tostring(be.roadTemplate) end
	local p = CC.posOf(e)
	if p then r.pos = { math.floor(p.x), math.floor(p.y) } end
	out[#out + 1] = r
end
return out

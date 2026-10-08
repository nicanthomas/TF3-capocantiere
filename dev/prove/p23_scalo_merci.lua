-- PROVA 23 (rischio crash: salvataggio pronto): scalo merci con lo schema copiato da uno fatto a mano (1 binario,
-- 160 m, marciapiede merci 64xxxxx su due colonne, edificio 3701980), vicino a un'industria asciutta e lontana dal bordo.
local best
for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY))) do
	local n = CC.nameOf(e) or ""
	local q = CC.posOf(e)
	local wet = false
	if q then for a = 0, 315, 45 do local r = math.rad(a); if CC.onWater(q.x + math.cos(r) * 150, q.y + math.sin(r) * 150) then wet = true end end end
	if q and not wet and CC.inMap(q.x, q.y, 1500) and not best then best = e end
end
local p = CC.posOf(best)
local name = (CC.nameOf(best) or "Industria") .. " scalo merci"
local st, why = CC.placeRailStation(p, 1, 0, {}, name, {
	builder = CC.cargoStationBuilder(name), Rs = { 120, 180, 250, 350, 500 }, maxTries = 6,
	score = function(x, y) return -math.sqrt((x - p.x) ^ 2 + (y - p.y) ^ 2) end,
	accept = function(info)
		if CC.stationCatches(info.station, best) then return true end
		return false, "l'industria non e' nel bacino"
	end,
})
local out = { industry = CC.nameOf(best), ok = st ~= nil, why = why }
if st then
	out.ends = #st.ends
	out.construction = st.construction
	out.group = st.group
	out.pos = st.site
end
return out

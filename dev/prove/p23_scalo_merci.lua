-- PROVA 23 (rischio crash: salvataggio pronto): scalo merci a 2 binari con edificio merci e scale, isolato, in un
-- posto libero vicino a un'industria. Se il gioco non va in crash e lo scalo vede l'industria, gli scali si sbloccano.
CC.CARGO_MODULES_OK = true
local best
for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY))) do
	local n = CC.nameOf(e) or ""
	if not n:find("Centauro", 1, true) and not best then best = e end
end
local p = CC.posOf(best)
local plan = CC.planStation({ kind = "cargo", trains = 1, lines = 1, train_len = 120 })
local st, info = CC.placeStationSmart(p, 1, 0, {}, "Prova p23 scalo", plan, {})
local out = { industry = CC.nameOf(best), plan = plan, ok = st ~= nil, steps = info and info.steps }
if st then
	out.ends = #st.ends
	out.catches = CC.stationCatches(st.station, best)
	out.construction = st.construction
end
CC.CARGO_MODULES_OK = nil
return out

-- PROVA 17: stazione a 4 binari da 240 m (piano automatico) vicino a una citta', senza collegarla. Poi la toglie.
local t = T.towns()[1]
local plan = CC.planStation({ kind = "passengers", trains = 4, lines = 2, train_len = 220 })
local st, info = CC.placeStationSmart(CC.posOf(t.id), 1, 0, {}, "Prova p17", plan, {})
local out = { plan = plan, ok = st ~= nil, steps = info and info.steps, used = info and info.plan }
if st then
	out.ends = #st.ends
	out.length = st.length
	CC.removeEdges(st.edges)
	out.removed = CC.removeConstruction(st.construction)
end
return out

-- PROVA 38: segnali a doppio senso ogni 400 m su una linea a binario unico gia' fatta (p14, 09.10.2026), un comando
-- per segnale (CC.placeSignals). Verifica del caso "piu' binari" che in p14 dava "Unknown exception".
local edges = { 90240, 90053, 90160, 89969, 89950, 89625, 89877, 89870, 89813, 89685, 89809, 89892, 89861, 89697, 89761,
	90377, 89788, 89904, 89914, 89694, 89758, 90085, 90401, 89796, 89688, 89691, 90527, 90528, 84965, 89648, 89649, 89650, 90189 }
local live = {}
for _, e in ipairs(edges) do
	local be = CC.comp(e, api.type.ComponentType.BASE_EDGE)
	if be and tostring(be.roadTemplate):find("/track/", 1, true) then live[#live + 1] = e end
end
local p = CC.posOf(89805)
local ok, r = CC.addSignals(live, { every = 400, oneWay = false, from = p })
return { ok = ok, live = #live, signals = r and r.signals, error = r and r.error, warning = r and r.warning }

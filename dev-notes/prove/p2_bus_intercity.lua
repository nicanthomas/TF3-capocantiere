-- PROVA 2: bus tra due citta' vicine (riusa le fermate esistenti in centro).
local p = T.townPair(1200, 5000, 2500)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_intercity_bus({ town_ids = { p[1].id, p[2].id }, num_vehicles = 2 })
r.towns = { p[1].name, p[2].name, p.d }
return r

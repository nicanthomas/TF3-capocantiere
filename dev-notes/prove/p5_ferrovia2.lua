-- PROVA 5: ferrovia passeggeri v2 (stazioni nel posto con piu' edifici + navetta bus stazione-centro).
local p = T.townPair(2000, 6000, 3500)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_rail_line2({ town_ids = { p[1].id, p[2].id }, num_trains = 2, num_cars = 3 })
r.towns = { p[1].name, p[2].name, p.d }
return r

-- PROVA 20: linea aerea tra le 2 citta' piu' lontane (oltre 6 km) con lo schema "airfield".
local p = T.townPair(6000, 30000, 12000)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_air_or_water_line({ town_ids = { p[1].id, p[2].id }, kind = "airfield", num_vehicles = 1, name = "Prova p20 aerei" })
r.towns = { p[1].name, p[2].name, p.d }
return r

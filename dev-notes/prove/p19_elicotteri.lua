-- PROVA 19: linea di elicotteri tra 2 citta' a 2-6 km con lo schema "helipad" (copiato dal salvataggio di terzi).
local p = T.townPair(2000, 6000, 3500)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_air_or_water_line({ town_ids = { p[1].id, p[2].id }, kind = "helipad", num_vehicles = 1, name = "Prova p19 elicotteri" })
r.towns = { p[1].name, p[2].name, p.d }
return r

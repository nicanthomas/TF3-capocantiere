-- PROVA 13: ferrovia a doppio binario tra 2 citta' con 2 treni (segnali a senso unico).
-- Prima eseguire la sonda s8 (modello dei segnali) e impostare CC.SIGNAL_MODEL se serve.
local p = T.townPair(2000, 6000, 3500)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_rail_line2({ town_ids = { p[1].id, p[2].id }, num_trains = 2, num_cars = 3, double_track = true, feeder = false })
r.towns = { p[1].name, p[2].name, p.d }
return r

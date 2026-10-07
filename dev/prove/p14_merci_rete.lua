-- PROVA 14: linea merci a piu' fermate (raccolta da un'industria, consegna a quella che usa la merce, ritorno se c'e'),
-- 2 treni (binari d'attesa se i binari degli scali non bastano).
local p = T.industryPair(1500, 7000)
if not p then return "nessuna coppia di industrie adatta" end
local r = SIM_ACTIONS.build_cargo_rail_network({ pickup_ids = { p.from.id }, delivery_ids = { p.to.id }, num_trains = 2, num_cars = 5 })
r.pair = { p.from.name, p.to.name, p.cargo, p.d }
return r

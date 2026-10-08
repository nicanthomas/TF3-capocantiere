-- PROVA 4: treno merci tra un'industria e una che usa la sua merce (stazioni merci, binari, treno).
-- Se manca il modulo merci, prima eseguire la sonda s3 (o s6 su una stazione merci fatta a mano).
local p = T.industryPair(1500, 7000)
if not p then return "nessuna coppia di industrie adatta" end
local r = SIM_ACTIONS.build_cargo_rail_line({ industry_id = p.from.id, target_id = p.to.id, num_trains = 1, num_cars = 4 })
r.pair = { p.from.name, p.to.name, p.cargo, p.d }
return r

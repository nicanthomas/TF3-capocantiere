-- PROVA 35 (punto 1a, opzione A): anello ferroviario tra 3 citta' vicine con DOPPIO BINARIO (un binario per senso,
-- segnali di percorso a senso unico con il metodo verificato in p34), linee nei due sensi, 2 treni per senso.
local ts = T.towns()
if #ts < 3 then return "servono 3 citta'" end
local base = ts[1]
table.sort(ts, function(a, b) return (a.x - base.x) ^ 2 + (a.y - base.y) ^ 2 < (b.x - base.x) ^ 2 + (b.y - base.y) ^ 2 end)
local ids = { ts[1].id, ts[2].id, ts[3].id }
local r = SIM_ACTIONS.build_rail_ring({ town_ids = ids, both_directions = true, trains_per_direction = 2, num_cars = 3, double_track = true })
r.towns = { ts[1].name, ts[2].name, ts[3].name }
return r

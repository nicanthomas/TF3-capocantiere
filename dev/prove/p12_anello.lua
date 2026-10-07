-- PROVA 12: ferrovia ad anello tra 3 citta' vicine, linee nei due sensi, 1 treno per senso (binario unico).
local ts = T.towns()
if #ts < 3 then return "servono 3 citta'" end
local base = ts[1]
table.sort(ts, function(a, b) return (a.x - base.x) ^ 2 + (a.y - base.y) ^ 2 < (b.x - base.x) ^ 2 + (b.y - base.y) ^ 2 end)
local ids = { ts[1].id, ts[2].id, ts[3].id }
local r = SIM_ACTIONS.build_rail_ring({ town_ids = ids, both_directions = true, trains_per_direction = 1, num_cars = 3 })
r.towns = { ts[1].name, ts[2].name, ts[3].name }
return r

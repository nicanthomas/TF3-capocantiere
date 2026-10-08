-- PROVA 25: linee nei due sensi sulle stazioni dell'anello gia' costruito (create_line_from_stations, pattern ring).
local gs = {}
for gg in pairs(CC.playerGroups()) do if CC.groupCarriers(gg).rail then gs[#gs + 1] = gg end end
if #gs < 3 then return { error = "servono 3 stazioni", n = #gs } end
-- ordine lungo l'anello: per angolo attorno al baricentro
local cx, cy = 0, 0
local P = {}
for i, g in ipairs(gs) do P[i] = CC.posOf(g); cx = cx + P[i].x / #gs; cy = cy + P[i].y / #gs end
local idx = {}
for i = 1, #gs do idx[i] = i end
table.sort(idx, function(a, b) return math.atan2(P[a].y - cy, P[a].x - cx) < math.atan2(P[b].y - cy, P[b].x - cx) end)
local ordered = {}
for k, i in ipairs(idx) do ordered[k] = gs[i] end
local r = SIM_ACTIONS.create_line_from_stations({ station_ids = ordered, pattern = "ring", both_directions = true, vehicle = "train", count = 1, num_cars = 3, name = "Anello prova" })
r.order = {}
for _, g in ipairs(ordered) do r.order[#r.order + 1] = CC.nameOf(g) end
return r

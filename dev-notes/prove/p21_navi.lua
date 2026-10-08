-- PROVA 21: linea di navi tra 2 citta' sulla costa con lo schema "harbor" (piccolo).
local best
local ts = T.towns()
local function coastal(t)
	for a = 0, 315, 45 do
		local r = math.rad(a)
		for d = 200, 2000, 200 do if CC.onWater(t.x + math.cos(r) * d, t.y + math.sin(r) * d) then return d end end
	end
end
local cs = {}
for _, t in ipairs(ts) do local d = coastal(t); if d then cs[#cs + 1] = t end end
for i = 1, #cs do for j = i + 1, #cs do
	local d = math.sqrt((cs[i].x - cs[j].x) ^ 2 + (cs[i].y - cs[j].y) ^ 2)
	if d > 2500 and (not best or d < best.d) then best = { cs[i], cs[j], d = math.floor(d) } end
end end
if not best then return { error = "nessuna coppia di citta' sulla costa", coastal = #cs } end
local r = SIM_ACTIONS.build_air_or_water_line({ town_ids = { best[1].id, best[2].id }, kind = "harbor", num_vehicles = 1, name = "Prova p21 navi" })
r.towns = { best[1].name, best[2].name, best.d }
return r

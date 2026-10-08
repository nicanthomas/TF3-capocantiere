-- PROVA 18: scalo merci vicino a un'industria collegato con un raccordo al binario del giocatore piu' vicino
-- (traffico misto sulla stessa linea). Serve una ferrovia gia' costruita entro 3 km da un'industria.
local best
for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(api.type.ComponentType.INDUSTRY))) do
	local p = CC.posOf(e)
	local tr = p and CC.nearestTrack(p.x, p.y, 3000)
	if tr and (not best or tr.d < best.d) then best = { ind = e, d = tr.d } end
end
if not best then return "nessuna industria vicino a un binario del giocatore" end
local r = SIM_ACTIONS.build_rail_station({ near_id = best.ind, kind = "cargo", trains = 1 })
r.industry = { best.ind, CC.nameOf(best.ind), math.floor(best.d) }
return r

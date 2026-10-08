-- PROVA 9 (dopo aver costruito a mano un aeroporto o porto lontano dalle strade): strada d'accesso automatica
-- per la costruzione del giocatore piu' recente.
local CT = api.type.ComponentType
local best
for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
	local po = CC.comp(con, CT.PLAYER_OWNED)
	if po and po.player == api.engine.util.getPlayer() and (not best or con > best) then best = con end
end
if not best then return "nessuna costruzione del giocatore" end
local ok, msg = CC.ensureRoadAccess(best, 400)
return { construction = best, file = tostring(CC.comp(best, CT.CONSTRUCTION).fileName), ok = ok, msg = msg }

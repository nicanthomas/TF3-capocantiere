-- PROVA 10: comando diretto "costruisci deposito" (strada vicino a una citta', ferrovia vicino a una stazione
-- del giocatore se c'e').
local t = T.towns()[1]
local out = { road = SIM_ACTIONS.build_depot({ kind = "road", town_id = t.id }) }
for g in pairs(CC.playerGroups()) do
	if CC.groupCarriers(g).rail then out.rail = SIM_ACTIONS.build_depot({ kind = "rail", station_id = g }); out.station = g; break end
end
return out

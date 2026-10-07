-- PROVA 11: linea su stazioni gia' costruite (prime due fermate bus del giocatore), andata e ritorno.
local gs = {}
for g in pairs(CC.playerGroups()) do
	local c = CC.groupCarriers(g)
	if c.road and not c.rail then gs[#gs + 1] = g end
	if #gs == 2 then break end
end
if #gs < 2 then return "servono 2 fermate stradali del giocatore" end
return SIM_ACTIONS.create_line_from_stations({ station_ids = gs, pattern = "back_forth", vehicle = "bus", count = 2, name = "Prova p11" })

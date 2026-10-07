-- PROVA 3: gestione veicoli su una linea bus del giocatore: +1, -1, sostituzione con modelli recenti.
local L
for _, l in ipairs(T.lines()) do if l.folder == "bus" and l.vehicles >= 1 then L = l; break end end
if not L then return "nessuna linea bus con veicoli" end
local out = { line = L }
out.add = SIM_ACTIONS.add_vehicles({ line_id = L.id, count = 1 })
out.remove = SIM_ACTIONS.remove_vehicles({ line_id = L.id, count = 1 })
out.replace = SIM_ACTIONS.replace_vehicles({ line_id = L.id })
out.after = #CC.lineVehicles(L.id)
return out

-- PROVA 44 (punto 4b): adjust_line_fleet su una linea bus e una merci su strada, solo proposta, poi applicata sul bus.
local out = {}
out.bus = SIM_ACTIONS.adjust_line_fleet({ line_id = 89994 })
out.camion = SIM_ACTIONS.adjust_line_fleet({ line_id = 89641 })
out.treno = SIM_ACTIONS.adjust_line_fleet({ line_id = 90082 })
out.bus_apply = SIM_ACTIONS.adjust_line_fleet({ line_id = 89994, apply = true, interval = 200 })
return out

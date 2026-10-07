-- PROVA 6: costruisce un bus tra citta' e lo annulla subito con quanto registrato in result.created.
local p = T.townPair(1200, 5000, 2000)
if not p then return "nessuna coppia di citta' adatta" end
local r = SIM_ACTIONS.build_intercity_bus({ town_ids = { p[1].id, p[2].id }, num_vehicles = 1 })
local u = r.created and SIM_ACTIONS.undo({ created = r.created })
return { built = { ok = r.ok, line = r.line_id, created = r.created }, undo = u,
	lineStillThere = r.line_id and CC.comp(r.line_id, api.type.ComponentType.LINE) ~= nil }

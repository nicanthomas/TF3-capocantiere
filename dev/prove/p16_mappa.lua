-- PROVA 16: lettura della mappa per Claude (citta', industrie, quote, acqua).
local r = SIM_ACTIONS.read_map({ grid = 8 })
r.heights = r.heights and #r.heights      -- non serve leggerle tutte qui
return r

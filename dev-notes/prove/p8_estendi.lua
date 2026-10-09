-- PROVA 8: allunga una linea bus del giocatore fino alla citta' piu' vicina non servita (makeLineUpdateCmd).
local L
for _, l in ipairs(T.lines()) do if l.folder == "bus" then L = l; break end end
if not L then return "nessuna linea bus" end
local g = CC.lineGroups(L.id)
local p0 = CC.posOf(g[#g])
local best, bd
for _, t in ipairs(T.towns()) do
	local d = math.sqrt((t.x - p0.x) ^ 2 + (t.y - p0.y) ^ 2)
	-- (09.10.2026) lontana da TUTTE le fermate della linea (prima sceglieva la citta' del primo capolinea)
	local far = true
	for _, gg in ipairs(g) do local q = CC.posOf(gg); if q and math.sqrt((t.x - q.x) ^ 2 + (t.y - q.y) ^ 2) < 800 then far = false end end
	if far and (not bd or d < bd) then best, bd = t, d end
end
if not best then return "nessuna citta' vicina" end
local r = SIM_ACTIONS.extend_line({ line_id = L.id, town_id = best.id })
r.line, r.town = L, { best.name, math.floor(bd) }
return r

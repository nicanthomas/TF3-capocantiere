-- SONDA 6 (sola lettura): copia i parametri (file .con, moduli, orientamento) delle costruzioni del giocatore
-- piu' recenti. Uso stasera: costruisci A MANO una stazione merci, un campo d'aviazione/aeroporto, un eliporto
-- e un porto, poi esegui questa sonda: i parametri diventano lo schema che la mod usera' (come per la stazione
-- ferroviaria passeggeri, copiata da una costruita nel gioco).
local CT = api.type.ComponentType
local player = api.engine.util.getPlayer()
local list = {}
for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
	local po = CC.comp(con, CT.PLAYER_OWNED)
	if po and po.player == player then list[#list + 1] = con end
end
table.sort(list, function(a, b) return a > b end)   -- id piu' alti = costruite piu' di recente
local out = {}
for i = 1, math.min(8, #list) do
	local con = list[i]
	local c = CC.comp(con, CT.CONSTRUCTION)
	-- params e modules nello stesso formato usato per costruire (numeri restano numeri): si copiano cosi' come sono
	-- in CC.TEMPLATES (vedi dev/bozza/b4_template.lua)
	local r = { id = con, file = tostring(c.fileName), pos = CC.posOf(con), params = {}, modules = {} }
	pcall(function()
		for k, v in pairs(c.params) do
			if k == "modules" then
				for slot, m in pairs(v) do r.modules[slot] = { name = tostring(m.name), variant = m.variant } end
			elseif type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
				r.params[tostring(k)] = v
			end
		end
	end)
	-- da che parte c'e' l'acqua (per i porti): controllo i 4 lati a 60 m dal centro, in coordinate locali
	pcall(function()
		local m = c.transf
		local cx, cy = m[13], m[14]
		local X, Y = { m[1], m[2] }, { m[5], m[6] }
		r.water = {
			["+Y"] = CC.onWater(cx + Y[1] * 60, cy + Y[2] * 60), ["-Y"] = CC.onWater(cx - Y[1] * 60, cy - Y[2] * 60),
			["+X"] = CC.onWater(cx + X[1] * 60, cy + X[2] * 60), ["-X"] = CC.onWater(cx - X[1] * 60, cy - X[2] * 60),
		}
	end)
	pcall(function()
		local m = c.transf
		r.transf = { m[1], m[2], m[5], m[6], m[13], m[14], m[15] }
	end)
	pcall(function() r.stations = #CC.each(c.stations); r.depots = #CC.each(c.depots) end)
	pcall(function()
		local st = CC.each(c.stations)[1]
		if st then
			r.catchables = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(st, true))
		end
	end)
	out[#out + 1] = r
end
return out

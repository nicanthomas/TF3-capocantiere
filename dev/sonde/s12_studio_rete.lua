-- SONDA 12 (sola lettura): studio di una rete costruita da altri (salvataggio di terzi).
-- Riassume: costruzioni del giocatore per tipo (file .con) con 1-2 esempi completi di parametri e moduli (= schemi
-- pronti per CC.TEMPLATES: aeroporti, porti, eliporti, scali merci...), binari e strade per tipo, oggetti sui binari
-- (segnali), linee (fermate, veicoli, modelli) e stato dei veicoli.
local CT = api.type.ComponentType
local player = api.engine.util.getPlayer()
local out = { constructions = {}, samples = {}, edges = { track = {}, street = {} }, edgeObjects = 0, lines = {},
	vehicleStates = {}, lineCount = 0 }

-- costruzioni del giocatore
local byFile = {}
for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
	local po = CC.comp(con, CT.PLAYER_OWNED)
	if po and po.player == player then
		local c = CC.comp(con, CT.CONSTRUCTION)
		local f = c and tostring(c.fileName) or "?"
		byFile[f] = (byFile[f] or 0) + 1
		out.samples[f] = out.samples[f] or {}
		if #out.samples[f] < 2 then
			local r = { id = con, name = CC.nameOf(con), params = {}, modules = {}, nModules = 0 }
			pcall(function()
				for k, v in pairs(c.params) do
					if k == "modules" then
						for slot, m in pairs(v) do
							r.nModules = r.nModules + 1
							if r.nModules <= 150 then r.modules[tostring(slot)] = { name = tostring(m.name), variant = m.variant } end
						end
					elseif type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
						r.params[tostring(k)] = v
					end
				end
			end)
			pcall(function() local m = c.transf; r.transf = { m[1], m[2], m[5], m[6], m[13], m[14], m[15] } end)
			pcall(function() r.stations = #CC.each(c.stations); r.depots = #CC.each(c.depots) end)
			out.samples[f][#out.samples[f] + 1] = r
		end
	end
end
for f, n in pairs(byFile) do out.constructions[#out.constructions + 1] = { file = f, count = n } end
table.sort(out.constructions, function(a, b) return a.count > b.count end)

-- binari e strade per tipo, oggetti sui binari (via octree: getEntitiesWithComponent(BASE_EDGE) non e' permesso)
local seenE = {}
for gx = -8000, 8000, 2000 do
	for gy = -8000, 8000, 2000 do
		pcall(function()
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1450, CT.BASE_EDGE))) do
				if not seenE[e] then
					seenE[e] = true
					local be = CC.comp(e, CT.BASE_EDGE)
					local tr = CC.comp(e, CT.BASE_EDGE_TRACK)
					local st = CC.comp(e, CT.BASE_EDGE_STREET)
					if tr then
						local k = tostring(tr.trackType) .. "/cat" .. tostring(tr.catenary)
						out.edges.track[k] = (out.edges.track[k] or 0) + 1
						local n = 0
						pcall(function() n = #CC.each(be.objects) end)
						out.edgeObjects = out.edgeObjects + n
					elseif st then
						local k = tostring(st.streetType)
						out.edges.street[k] = (out.edges.street[k] or 0) + 1
					end
				end
			end
		end)
	end
end

-- linee: fermate, veicoli, modelli (prime 40), conteggio per numero di fermate
local lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(player))
out.lineCount = #lines
out.stopsHistogram = {}
for i, L in ipairs(lines) do
	local lc = CC.comp(L, CT.LINE)
	local stops = {}
	pcall(function() for _, s in ipairs(CC.each(lc.stops)) do stops[#stops + 1] = { g = s.stationGroup, t = s.terminal } end end)
	local k = tostring(#stops)
	out.stopsHistogram[k] = (out.stopsHistogram[k] or 0) + 1
	local vs = {}
	pcall(function() vs = CC.each(api.engine.system.transportVehicleSystem.getLineVehicles(L)) end)
	for _, v in ipairs(vs) do
		local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
		local st = tv and tostring(tv.state) or "?"
		out.vehicleStates[st] = (out.vehicleStates[st] or 0) + 1
	end
	if i <= 40 then
		local models = {}
		pcall(function()
			local tv = CC.comp(vs[1], CT.TRANSPORT_VEHICLE)
			for _, p in ipairs(CC.each(tv.transportVehicleConfig.vehicles)) do
				if #models < 6 then models[#models + 1] = api.res.modelRep.getName(p.part.modelId) end
			end
			models.parts = #CC.each(tv.transportVehicleConfig.vehicles)
		end)
		out.lines[#out.lines + 1] = { id = L, name = CC.nameOf(L), stops = stops, vehicles = #vs, models = models }
	end
end
return out

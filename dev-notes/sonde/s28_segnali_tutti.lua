-- SONDA 28 (sola lettura, 08.10.2026): trovare i SEGNALI nella partita di terzi. s26 non ne ha trovati (oggetti
-- vuoti su 1303 binari letti, tutti high_speed) e s8 si fermava su pairs(CT) (nomi userdata nella 40420).
-- Metodi: (1) nomi dei ComponentType; (2) getEntitiesWithComponent su SIGNAL_LIST e simili; (3) binari su tutta la
-- mappa (CC.mapBox) con be.objects letti in piu' modi; (4) costruzioni con "signal" nel file.
local CT = api.type.ComponentType
local out = { ct = {}, perTipo = {}, esempi = {}, mappa = nil, binari = { letti = 0, conOggetti = 0, tipi = {} }, oggetti = {} }
local function plainish(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 3 then return tostring(v) end
	local r = {}
	local ok = pcall(function() for k, x in pairs(v) do r[tostring(k)] = plainish(x, depth + 1) end end)
	if not ok or next(r) == nil then
		pcall(function() local n = v:size(); r.n = n; for i = 1, math.min(n, 6) do r["at" .. i] = plainish(v:at(i), depth + 1) end end)
		for _, f in ipairs({ "x", "y", "z", "entity", "edgeEntity", "edge", "param", "left", "oneWay", "type", "model",
			"modelId", "state", "signalType", "signals", "edgePr", "fileName", "name", "transf", "modelInstances", "objects" }) do
			pcall(function() local x = v[f]; if x ~= nil then r[f] = plainish(x, depth + 1) end end)
		end
		if next(r) == nil then return tostring(v) end
	end
	return r
end
-- (1) nomi dei tipi di componente
local names = {}
pcall(function() for k, id in pairs(CT) do local s = tostring(k); names[#names + 1] = s; out.ct[s] = tostring(id) end end)
-- (2) entita' per tipo (solo i tipi che riguardano segnali/oggetti)
for _, s in ipairs(names) do
	if s:find("SIGNAL") or s:find("OBJECT") or s:find("WAYPOINT") then
		local ok, lst = pcall(api.engine.getEntitiesWithComponent, CT[s])
		if ok then
			local all = CC.each(lst)
			out.perTipo[s] = #all
			for i = 1, math.min(5, #all) do
				local e = all[i]
				local item = { entity = e, comps = {} }
				for _, s2 in ipairs(names) do
					local okC, c = pcall(api.engine.getComponent, e, CT[s2])
					if okC and c then item.comps[s2] = plainish(c) end
				end
				out.esempi[#out.esempi + 1] = { tipo = s, item = item }
			end
		else
			out.perTipo[s] = "ERR " .. tostring(lst):sub(1, 120)
		end
	end
end
-- (3) binari su tutta la mappa
pcall(function()
	local b = CC.mapBox()
	out.mappa = { minX = b.minX, maxX = b.maxX, minY = b.minY, maxY = b.maxY, src = b.src }
	local seen = {}
	for gx = b.minX + 1000, b.maxX, 1800 do
		for gy = b.minY + 1000, b.maxY, 1800 do
			pcall(function()
				for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1300, CT.BASE_EDGE))) do
					if not seen[e] then
						seen[e] = true
						local be = CC.comp(e, CT.BASE_EDGE)
						local tpl = be and tostring(be.roadTemplate) or ""
						if tpl:find("/track/", 1, true) then
							out.binari.letti = out.binari.letti + 1
							local short = tpl:gsub("^.*/track/", "")
							out.binari.tipi[short] = (out.binari.tipi[short] or 0) + 1
							local n = 0
							pcall(function() n = be.objects:size() end)
							if n == 0 then pcall(function() n = #be.objects end) end
							if n > 0 then
								out.binari.conOggetti = out.binari.conOggetti + 1
								if #out.oggetti < 12 then
									local objs = {}
									pcall(function() for i = 1, n do objs[#objs + 1] = plainish(be.objects:at(i)) end end)
									if #objs == 0 then pcall(function() for i = 0, n - 1 do objs[#objs + 1] = plainish(be.objects[i]) end end) end
									local first = be.objects
									local ent
									pcall(function() local o = be.objects:at(1); ent = o[1] or o.entity or o.x end)
									local ec = {}
									if type(ent) == "number" then
										for _, s2 in ipairs(names) do
											local okC, c = pcall(api.engine.getComponent, ent, CT[s2])
											if okC and c then ec[s2] = plainish(c) end
										end
									end
									out.oggetti[#out.oggetti + 1] = { edge = e, template = short, n = n, objs = objs, entity = ent, comps = ec,
										p0 = string.format("%.1f %.1f %.1f", be.position0.x, be.position0.y, be.position0.z),
										p1 = string.format("%.1f %.1f %.1f", be.position1.x, be.position1.y, be.position1.z),
										node0 = be.node0, node1 = be.node1 }
								end
							end
						end
					end
				end
			end)
		end
	end
end)
-- (4) modelli di segnale disponibili
out.modelli = {}
pcall(function()
	api.res.modelRep.forEachModelWithMetadata("signal", function(name) if #out.modelli < 40 then out.modelli[#out.modelli + 1] = tostring(name) end end)
end)
return out

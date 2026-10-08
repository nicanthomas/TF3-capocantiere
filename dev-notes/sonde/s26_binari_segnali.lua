-- SONDA 26 (sola lettura): binari, segnali e strade su TUTTA la mappa (griglia di cerchi con l'octree).
-- Correzione dello studio del 07.10: la sonda s12 usava CT.BASE_EDGE_TRACK, che NON esiste, quindi gli oggetti sui
-- binari (segnali) risultavano sempre 0. Qui un binario si riconosce dal roadTemplate "/track/".
-- Raccoglie: tipi di binario/strada/ponte/galleria con conteggi, binari con oggetti (fino a CC.PROBE_MAX_SIGNALS,
-- default 30, con componenti e modello), e coppie di binari paralleli vicini (doppio binario: distanza tipica).
local CT = api.type.ComponentType
local out = { tipi_binario = {}, tipi_strada = {}, ponti = {}, gallerie = {}, oggetti_per_modello = {}, segnali = {}, doppio = {} }
local MAXS = CC.PROBE_MAX_SIGNALS or 30
local function short(n) return (tostring(n):gsub("^::/", "")) end
local function compsOf(ent)
	local r = {}
	for name, id in pairs(CT) do
		if name:find("SIGNAL") or name:find("OBJECT") then
			local okC, comp = pcall(api.engine.getComponent, ent, id)
			if okC and comp then
				local f = {}
				pcall(function() for k, v in pairs(comp) do f[#f + 1] = tostring(k) .. "=" .. tostring(v):sub(1, 80) end end)
				r[name] = (#f > 0) and table.concat(f, "; ") or tostring(comp):sub(1, 300)
			end
		end
	end
	pcall(function()
		local mil = api.engine.getComponent(ent, CT.MODEL_INSTANCE_LIST)
		for _, fi in ipairs(CC.each(mil.fatInstances)) do r.model = tostring(api.res.modelRep.getName(fi.modelId)); break end
	end)
	return r
end
local seen, tracks = {}, {}
for gx = -8000, 8000, 2000 do
	for gy = -8000, 8000, 2000 do
		pcall(function()
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1450, CT.BASE_EDGE))) do
				if not seen[e] then
					seen[e] = true
					local be = CC.comp(e, CT.BASE_EDGE)
					if be then
						local tpl = short(be.roadTemplate)
						local isTrack = tpl:find("/track/", 1, true) ~= nil
						local bucket = isTrack and out.tipi_binario or out.tipi_strada
						bucket[tpl] = (bucket[tpl] or 0) + 1
						pcall(function()
							if be.type == 1 then out.ponti[tostring(be.typeIndex)] = (out.ponti[tostring(be.typeIndex)] or 0) + 1 end
							if be.type == 2 then out.gallerie[tostring(be.typeIndex)] = (out.gallerie[tostring(be.typeIndex)] or 0) + 1 end
						end)
						if isTrack then
							if #tracks < 4000 then
								tracks[#tracks + 1] = { e = e, x = (be.position0.x + be.position1.x) / 2, y = (be.position0.y + be.position1.y) / 2,
									dx = be.position1.x - be.position0.x, dy = be.position1.y - be.position0.y }
							end
							local objs = {}
							pcall(function() for _, o in ipairs(CC.each(be.objects)) do objs[#objs + 1] = o end end)
							for _, o in ipairs(objs) do
								local ent = o
								pcall(function() if type(o) ~= "number" then ent = o[1] or o.entity end end)
								local info = (type(ent) == "number") and compsOf(ent) or {}
								local key = info.model or "?"
								out.oggetti_per_modello[key] = (out.oggetti_per_modello[key] or 0) + 1
								if #out.segnali < MAXS then
									local f = {}
									pcall(function() for k, v in pairs(o) do f[#f + 1] = tostring(k) .. "=" .. tostring(v) end end)
									out.segnali[#out.segnali + 1] = { edge = e, template = tpl, node0 = be.node0, node1 = be.node1,
										p0 = string.format("%.1f %.1f %.1f", be.position0.x, be.position0.y, be.position0.z),
										p1 = string.format("%.1f %.1f %.1f", be.position1.x, be.position1.y, be.position1.z),
										objRaw = tostring(o):sub(1, 150), objFields = f, entity = ent, comps = info }
								end
							end
						end
					end
				end
			end
		end)
	end
end
-- doppio binario: per 300 binari, il binario parallelo piu' vicino (stessa direzione) entro 20 m
local dist = {}
for i = 1, math.min(#tracks, 300) do
	local a = tracks[i]
	local la = math.sqrt(a.dx * a.dx + a.dy * a.dy)
	if la > 20 then
		local best
		for j = 1, #tracks do
			if j ~= i then
				local b = tracks[j]
				local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
				if d < 20 then
					local lb = math.sqrt(b.dx * b.dx + b.dy * b.dy)
					local cos = math.abs((a.dx * b.dx + a.dy * b.dy) / (la * lb + 1e-9))
					if cos > 0.995 and (not best or d < best) then best = d end
				end
			end
		end
		if best then local k = string.format("%.1f", best); dist[k] = (dist[k] or 0) + 1 end
	end
end
out.doppio.distanze_binari_paralleli_m = dist
out.binari_letti = #tracks
pcall(function() out.signalSystem = {}; for k in pairs(api.engine.system.signalSystem) do out.signalSystem[#out.signalSystem + 1] = tostring(k) end end)
return out

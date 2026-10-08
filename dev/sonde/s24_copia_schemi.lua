-- SONDA 24 (sola lettura): copia gli SCHEMI di tutto quello che serve da una partita gia' costruita (es. il
-- salvataggio di terzi "My 1st Sandbox with mods Final"): stazioni ferroviarie merci e passeggeri (moduli e parametri),
-- porti modulari, magazzini, depositi/officine di ogni tipo, impianti contro l'inquinamento, fermate stradali, e i
-- SEGNALI sui binari (componenti e modelli). Nel primo studio (07.10) erano stati copiati solo aerei/eliporti/porto:
-- questa sonda recupera il resto. Accesso UNA SOLA VOLTA: copiare tutto (disposizioni diverse e catalogo moduli).
local CT = api.type.ComponentType
local out = { schemi = {}, segnali = {}, conteggi = {} }

local function short(n) return (tostring(n):gsub("^::/", ""):gsub("stations/rail/modular_station/", "RS/"):gsub("trainstation___/infrastructure/track/", "T/")) end
local function category(file, mods)
	local f = tostring(file)
	if f:find("modular_station.con", 1, true) then
		for _, m in pairs(mods) do if m:find("cargo", 1, true) then return "rail_cargo" end end
		return "rail_passengers"
	end
	for _, k in ipairs({ "harbor", "warehouse", "rail_depot", "rail_maint", "road_depot", "road_maint", "tram_depot",
		"water_depot", "water_maint", "pollution", "modular_terminal", "underground_station", "airport", "airfield", "heli" }) do
		if f:find(k, 1, true) then return k end
	end
	return nil
end

local byCat = {}
for _, con in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
	local c = CC.comp(con, CT.CONSTRUCTION)
	local po = CC.comp(con, CT.PLAYER_OWNED)
	if c and po then
		local mods = {}
		pcall(function()
			for slot, m in pairs(c.params.modules or {}) do mods[#mods + 1] = tostring(slot) .. "=" .. short(m.name) .. "|" .. tostring(m.variant) end
		end)
		local cat = category(c.fileName, mods)
		if cat then
			out.conteggi[cat] = (out.conteggi[cat] or 0) + 1
			byCat[cat] = byCat[cat] or {}
			table.insert(byCat[cat], { con = con, c = c, mods = mods })
		end
	end
end

-- Per ogni tipo: TUTTE le disposizioni diverse (firma = file + elenco ordinato dei nomi dei moduli, senza slot),
-- fino a CC.PROBE_MAX_LAYOUTS (default 8) per tipo, dalle piu' semplici; piu' il catalogo dei moduli usati.
out.catalogo_moduli = {}
for cat, list in pairs(byCat) do
	table.sort(list, function(a, b) return #a.mods < #b.mods end)
	out.schemi[cat] = {}
	local cata, sigSeen, nLay = {}, {}, 0
	for _, it in ipairs(list) do
		local names = {}
		for _, m in ipairs(it.mods) do
			local n = m:match("=([^|]+)")
			if n then names[#names + 1] = n; cata[n] = (cata[n] or 0) + 1 end
		end
		table.sort(names)
		local sig = tostring(it.c.fileName) .. "#" .. table.concat(names, ",")
		if not sigSeen[sig] and nLay < (CC.PROBE_MAX_LAYOUTS or 8) then
			sigSeen[sig] = true
			nLay = nLay + 1
			local c = it.c
			local r = { id = it.con, name = CC.nameOf(it.con), file = short(c.fileName), params = {}, nModules = #it.mods }
			table.sort(it.mods)
			r.modules = (#it.mods <= 150) and it.mods or { "troppi moduli: " .. #it.mods }
			pcall(function()
				for k, v in pairs(c.params) do
					if k ~= "modules" and type(v) ~= "table" and type(v) ~= "userdata" then r.params[tostring(k)] = v end
				end
			end)
			pcall(function()
				local m = c.transf
				r.transf = string.format("%.4f %.4f %.4f %.4f %.1f %.1f %.2f", m[1], m[2], m[5], m[6], m[13], m[14], m[15])
			end)
			pcall(function() r.stations = #CC.each(c.stations); r.depots = #CC.each(c.depots) end)
			pcall(function() r.ends = #CC.railStationEnds(it.con) end)
			table.insert(out.schemi[cat], r)
		end
	end
	local cl = {}
	for n, k in pairs(cata) do cl[#cl + 1] = n .. " x" .. k end
	table.sort(cl)
	out.catalogo_moduli[cat] = cl
end

-- SEGNALI: binari con oggetti vicino alle stazioni ferroviarie (ricerca con l'octree: getEntitiesWithComponent(BASE_EDGE)
-- e' vietato). Si cerca in cerchi di 1500 m attorno a ogni stazione, fino a 8 binari con oggetti.
local function compsOf(ent)
	local r = {}
	for name, id in pairs(CT) do
		if name:find("SIGNAL") or name:find("OBJECT") or name:find("MODEL") then
			local okC, comp = pcall(api.engine.getComponent, ent, id)
			if okC and comp then
				local s = tostring(comp)
				pcall(function()
					local f = {}
					for k, v in pairs(comp) do f[#f + 1] = tostring(k) .. "=" .. tostring(v):sub(1, 80) end
					if #f > 0 then s = table.concat(f, "; ") end
				end)
				r[name] = s:sub(1, 600)
			end
		end
	end
	pcall(function()
		local mil = api.engine.getComponent(ent, CT.MODEL_INSTANCE_LIST)
		for _, fi in ipairs(CC.each(mil.fatInstances)) do r.model = tostring(api.res.modelRep.getName(fi.modelId)); break end
	end)
	return r
end
local seenEdge, found = {}, 0
for _, it in ipairs((byCat.rail_passengers or {})) do
	if found >= (CC.PROBE_MAX_SIGNAL_EDGES or 8) then break end
	local p = CC.posOf(it.con)
	if p then
		pcall(function()
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 1500, CT.BASE_EDGE))) do
				if found >= (CC.PROBE_MAX_SIGNAL_EDGES or 8) then break end
				if not seenEdge[e] then
					seenEdge[e] = true
					local be = CC.comp(e, CT.BASE_EDGE)
					if be and tostring(be.roadTemplate):find("/track/", 1, true) then
						local objs = {}
						pcall(function() for _, o in ipairs(CC.each(be.objects)) do objs[#objs + 1] = o end end)
						if #objs > 0 then
							found = found + 1
							local item = { edge = e, template = short(be.roadTemplate), objects = {} }
							for _, o in ipairs(objs) do
								local ent = o
								pcall(function() if type(o) ~= "number" then ent = o[1] or o.entity end end)
								local oi = { raw = tostring(o):sub(1, 200), entity = ent }
								pcall(function() oi.fields = {}; for k, v in pairs(o) do oi.fields[#oi.fields + 1] = tostring(k) .. "=" .. tostring(v) end end)
								if type(ent) == "number" then oi.comps = compsOf(ent) end
								table.insert(item.objects, oi)
							end
							table.insert(out.segnali, item)
						end
					end
				end
			end
		end)
	end
end
out.segnali_trovati = found
pcall(function() out.signalSystem = {}; for k in pairs(api.engine.system.signalSystem) do out.signalSystem[#out.signalSystem + 1] = tostring(k) end end)
return out

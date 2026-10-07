-- ===================================================================== BOZZA (NON TESTATO) - b4 aerei, elicotteri, navi, superstrade
-- Queste costruzioni non le conosciamo ancora: la strada e' la stessa usata per la stazione ferroviaria.
--   1. stasera si costruiscono A MANO un campo d'aviazione/aeroporto, un eliporto, un porto e un deposito navale;
--   2. la sonda s6 ne copia file .con, parametri e moduli;
--   3. i dati vanno in CC.TEMPLATES qui sotto e la mod li ripete dove serve.
-- Schemi riempiti il 07.10.2026 dalle costruzioni di un salvataggio di terzi (sonda s17). DA PROVARE in gioco.

CC.TEMPLATES = CC.TEMPLATES or {
	-- Copiati con la sonda s17 dal salvataggio di terzi (07.10.2026, vedi docs/studio-salvataggio-terzi.md).
	-- half = mezza dimensione massima in metri (dal bounding box); waterSide = lato locale con acqua a 30-100 m.
	airfield = { file = "::/stations/air/airfield.con", params = { hangar = 1, terminals = 3 },
		modules = { [10001000] = { name = "::/stations/air/airfield/af_hangar.module", variant = 0 }, [10001002] = { name = "::/stations/air/airfield/af_main.module", variant = 0 }, [10001004] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 }, [10001006] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 }, [10001008] = { name = "::/stations/air/airfield/af_terminal.module", variant = 0 } },
		half = 200, kind = "air" },   -- da: Brunssum Airport
	airport = { file = "::/stations/air/airport.con", params = { dir = 2, hangar = 1, terminals = 1 },
		modules = { [1008] = { name = "::/stations/air/airport/ap_main.module", variant = 0 }, [2000] = { name = "::/stations/air/airport/ap_hangar.module", variant = 0 }, [70003] = { name = "::/stations/air/airport/ap_terminal.module", variant = 0 }, [70012] = { name = "::/stations/air/airport/ap_terminal.module", variant = 0 }, [9000] = { name = "::/stations/air/airport/airport_era_c_landing_direction.module", variant = 0 } },
		half = 330, kind = "air" },   -- da: Geldrop-Mierlo Airport
	heliport = { file = "::/stations/air/heliport.con", params = {  },
		modules = nil,
		half = 75, kind = "air" },   -- da: Lisse Heliport
	helipad = { file = "::/stations/air/helipad.con", params = {  },
		modules = nil,
		half = 20, kind = "air" },   -- da: Winterswijk Heliport
	harbor = { file = "::/stations/water/harbor_modular.con", params = { smallterminals = 1 },
		modules = { [100009736] = { name = "::/stations/water/small_pier.module", variant = 0 }, [100009804] = { name = "::/stations/water/passenger_dock_50_12.module", variant = 0 }, [100010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [99010053] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [99010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 } },
		half = 40, kind = "water", waterSide = "-Y" },   -- da: Hilversum Port #1
	harbor_large = { file = "::/stations/water/harbor_modular.con", params = { largeterminals = 1 },
		modules = { [100009444] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [100009612] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [100009722] = { name = "::/stations/water/passenger_dock_100_50.module", variant = 0 }, [100010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [101010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [102010149] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [103008547] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [103010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [105008808] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [105009608] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [87008347] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [89008608] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [89009408] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [90008345] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [90009145] = { name = "::/stations/water/medium_pier.module", variant = 0 }, [92010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [93009855] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [93010055] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [93010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [94010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [95009611] = { name = "::/stations/water/passenger_dock_100_25.module", variant = 0 }, [95009754] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [95010055] = { name = "::/stations/water/passenger_dock_25_25.module", variant = 0 }, [95010151] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [96010151] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [97010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [98010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 }, [99010150] = { name = "::/stations/water/pedestrian_entrance.module", variant = 0 } },
		half = 160, kind = "water", waterSide = "-Y" },   -- da: Hilversum Port
	water_depot = { file = "::/depots/water/water_depot.con", params = {  },
		modules = nil,
		half = 80, kind = "water", waterSide = "-Y" },   -- da: Hilversum Ship Depot
}

-- Cartelle dei veicoli (dalla sonda s4): aerei, elicotteri, navi.
CC.VEHICLE_FOLDERS = CC.VEHICLE_FOLDERS or { plane = "plane", heli = "helicopter", ship = "ship" }

local function unit2(x, y) local l = math.sqrt(x * x + y * y); if l < 1e-6 then return 1, 0 end return x / l, y / l end

-- Costruisce lo schema tpl con centro (x, y) e asse locale Y lungo (dx, dy). Ritorna ok, info { construction,
-- groups, depots } o false, errore. Passa dalla verifica a secco (CC.buildCmd).
function CC.placeTemplate(tpl, x, y, dx, dy, name)
	local CT = api.type.ComponentType
	local z = CC.heightAt(x, y) or 0
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = tpl.file
	local params = { year = CC.year(), seed = 0 }
	for k, v in pairs(tpl.params or {}) do if k ~= "modules" and k ~= "year" and k ~= "seed" then params[k] = v end end
	if tpl.modules then
		local mods = {}
		for slot, m in pairs(tpl.modules) do mods[tonumber(slot) or slot] = { name = m.name, variant = m.variant or 0 } end
		params.modules = mods
	else
		params.modules = {}
	end
	ce.params = params     -- tutto insieme: il gioco copia la tabella
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(x, y, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = name or "Costruzione"
	prop.constructionsToAdd = { ce }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, tostring(cmd) end
	local ok, res, ents = CC.send(cmd)
	if not ok then
		local pe = CC.proposalErrors(res)
		return false, "rifiutata: " .. table.concat(pe.msg, "; ") .. (#pe.coll > 0 and (" (" .. #pe.coll .. " collisioni)") or "")
	end
	local out = { groups = {}, depots = {} }
	for _, e in ipairs(ents or {}) do
		local c = CC.comp(e, CT.CONSTRUCTION)
		if c then
			out.construction = out.construction or e
			for _, st in ipairs(CC.each(c.stations)) do
				local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
				if okG and g and g >= 0 then out.groups[#out.groups + 1] = g end
			end
			for _, d in ipairs(CC.each(c.depots)) do out.depots[#out.depots + 1] = d end
		end
	end
	if out.groups[1] and name then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(out.groups[1], name)) end) end
	return true, out
end

-- Strada d'accesso: nodi stradali liberi della costruzione collegati alla strada piu' vicina (entro maxD).
function CC.ensureRoadAccess(con, maxD)
	local CT = api.type.ComponentType
	local c = CC.comp(con, CT.CONSTRUCTION)
	if not c then return false, "costruzione inesistente" end
	local cand, seen = {}, {}
	for _, fn in ipairs(CC.each(c.frozenNodes)) do
		cand[#cand + 1] = fn
		for _, sg in ipairs(CC.each(api.engine.system.streetSystem.getNodeSegments(fn))) do
			local b = CC.comp(sg, CT.BASE_EDGE)
			if b then cand[#cand + 1] = b.node0; cand[#cand + 1] = b.node1 end
		end
	end
	local free = {}
	for _, n in ipairs(cand) do
		if not seen[n] then
			seen[n] = true
			local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(n))
			if #segs == 1 and CC.comp(segs[1], CT.BASE_EDGE_STREET) then free[#free + 1] = n end
		end
	end
	if #free == 0 then return true, "nessun accesso stradale libero (gia' collegata o non serve)" end
	local done = 0
	for _, n in ipairs(free) do
		local p = CC.comp(n, CT.BASE_NODE).position
		local best, bd
		for _, e in ipairs(CC.streetEdgesNear(p.x, p.y, maxD or 300, 5)) do
			local be = CC.comp(e.edge, CT.BASE_EDGE)
			for _, m in ipairs({ be.node0, be.node1 }) do
				if not seen[m] then
					local q = CC.comp(m, CT.BASE_NODE).position
					local d = math.sqrt((q.x - p.x) ^ 2 + (q.y - p.y) ^ 2)
					if not bd or d < bd then best, bd = m, d end
				end
			end
		end
		if best then
			local ok = CC.connectNodes(n, best, nil, false)
			if not ok then ok = CC.connectNodes(n, best, "::/infrastructure/street/town/town_old_small.street_template", false) end
			if ok then done = done + 1 end
		end
	end
	return done > 0, done .. " accessi stradali su " .. #free
end

-- Posto piano e asciutto attorno al centro per uno schema "air" (mezza lunghezza tpl.half).
local function airSites(center, tpl, Rs)
	local out = {}
	local half = tpl.half or 100
	for _, R in ipairs(Rs) do
		for a = 0, 330, 30 do
			local r = math.rad(a)
			local x, y = center.x + math.cos(r) * R, center.y + math.sin(r) * R
			for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 0.7071, 0.7071 }, { 0.7071, -0.7071 } }) do
				local dx, dy = d[1], d[2]
				local h0 = CC.heightAt(x, y)
				local h1 = CC.heightAt(x + dx * half, y + dy * half)
				local h2 = CC.heightAt(x - dx * half, y - dy * half)
				local h3 = CC.heightAt(x + dy * half * 0.5, y - dx * half * 0.5)
				local h4 = CC.heightAt(x - dy * half * 0.5, y + dx * half * 0.5)
				if h0 and h1 and h2 and h3 and h4 then
					local mx, mn = math.max(h0, h1, h2, h3, h4), math.min(h0, h1, h2, h3, h4)
					local wet = CC.onWater(x, y) or CC.onWater(x + dx * half, y + dy * half) or CC.onWater(x - dx * half, y - dy * half)
					local clear = CC.pathClear(x - dx * half, y - dy * half, x + dx * half, y + dy * half, half * 0.3)
					if not wet and clear and mx - mn < (tpl.maxSlope or 8) then
						out[#out + 1] = { x = x, y = y, dx = dx, dy = dy, R = R, flat = mx - mn }
					end
				end
			end
		end
	end
	table.sort(out, function(p, q) if p.R ~= q.R then return p.R < q.R end return p.flat < q.flat end)
	return out
end

-- Punto di costa piu' vicino al centro: cammino verso l'esterno finche' trovo acqua. dir = verso l'acqua.
local function shoreSites(center, maxR)
	local out = {}
	for a = 0, 337.5, 22.5 do
		local r = math.rad(a)
		local dx, dy = math.cos(r), math.sin(r)
		local lastLand
		for d = 0, maxR or 3000, 25 do
			local x, y = center.x + dx * d, center.y + dy * d
			if CC.onWater(x, y) then
				if lastLand then out[#out + 1] = { x = lastLand[1], y = lastLand[2], dx = dx, dy = dy, R = d } end
				break
			end
			lastLand = { x, y }
		end
	end
	table.sort(out, function(p, q) return p.R < q.R end)
	return out
end

-- Asse locale che deve guardare l'acqua -> orientamento (dx, dy) da passare a placeTemplate.
local function orientForWater(side, wx, wy)
	if side == "+Y" then return wx, wy end
	if side == "-Y" then return -wx, -wy end
	if side == "+X" then return -wy, wx end      -- X locale = (dy, -dx): voglio X = w  ->  d = (-wy, wx)
	if side == "-X" then return wy, -wx end
	return wx, wy
end

-- Costruisce lo schema `key` vicino alla citta'. Ritorna ok, info.
function CC.buildTemplateNear(key, town, name)
	local tpl = CC.TEMPLATES[key]
	if not tpl then return false, "schema '" .. key .. "' mancante: costruiscine uno a mano e copia i dati con la sonda s6" end
	local c = CC.posOf(town)
	if not c then return false, "citta' non trovata" end
	local tried = {}
	if tpl.kind == "water" then
		for i, s in ipairs(shoreSites(c, 4000)) do
			if i > 8 then break end
			local dx, dy = orientForWater(tpl.waterSide, s.dx, s.dy)
			local back = tpl.shoreBack or 0          -- di quanto arretrare dalla costa (dalla sonda: meta' profondita' sul terreno)
			local ok, info = CC.placeTemplate(tpl, s.x - s.dx * back, s.y - s.dy * back, dx, dy, name)
			if ok then return true, info end
			tried[#tried + 1] = info
		end
		return false, "nessun punto di costa adatto: " .. table.concat(tried, " | ")
	end
	for i, s in ipairs(airSites(c, tpl, tpl.Rs or { 500, 800, 1200, 1600, 2200 })) do
		if i > 10 then break end
		local ok, info = CC.placeTemplate(tpl, s.x, s.y, s.dx, s.dy, name)
		if ok then return true, info end
		tried[#tried + 1] = info
	end
	return false, "nessun posto piano e libero: " .. table.concat(tried, " | ")
end

-- ---------------------------------------------------------------- linee aeree / elicotteri / navi
-- kind: "airfield" | "airport" | "heliport" | "helipad" | "harbor" | "harbor_large"; cargo = true per le merci (veicoli senza posti).
SIM_ACTIONS.build_air_or_water_line = function(a)
	CC.need(a, { town_ids = "ints", kind = "str", num_vehicles = "int?", name = "str?" })
	local tpl = CC.TEMPLATES[a.kind]
	if not tpl then return { ok = false, error = "schema '" .. a.kind .. "' mancante (vedi sonda s6)" } end
	local folder = (a.kind == "heliport" or a.kind == "helipad") and CC.VEHICLE_FOLDERS.heli or (tpl.kind == "water" and CC.VEHICLE_FOLDERS.ship or CC.VEHICLE_FOLDERS.plane)
	local groups, depots, log = {}, {}, {}
	for i, t in ipairs(a.town_ids) do
		local ok, info = CC.buildTemplateNear(a.kind, t, (CC.nameOf(t) or "Citta'") .. " " .. a.kind)
		if not ok then return { ok = false, error = (CC.nameOf(t) or "?") .. ": " .. tostring(info), stations = groups, log = log } end
		if not info.groups[1] then return { ok = false, error = "costruito ma senza stazione", log = log } end
		groups[i] = info.groups[1]
		for _, d in ipairs(info.depots) do depots[#depots + 1] = d end
		local okR, msg = CC.ensureRoadAccess(info.construction, 400)
		log[#log + 1] = (CC.nameOf(t) or "?") .. ": costruito; strada d'accesso: " .. tostring(msg)
	end
	-- deposito: quello incluso nella costruzione (aeroporti) o uno schema a parte (deposito navale)
	local depot = depots[1]
	if not depot and CC.TEMPLATES.water_depot and tpl.kind == "water" then
		local ok, info = CC.buildTemplateNear("water_depot", a.town_ids[1], "Cantiere navale")
		if ok then depot = info.depots[1] else log[#log + 1] = "deposito navale: " .. tostring(info) end
	end
	if not depot then return { ok = false, error = "nessun deposito/hangar per i veicoli", stations = groups, log = log } end
	local okL, li = CC.createLine(a.name or ("Linea " .. a.kind), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, log = log } end
	local model = CC.pickModel(folder, nil, { passengers = not a.cargo })
	if a.cargo then
		-- merci: il modello piu' recente con capacita' merci
		model = nil
		api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(n)
			if n:find("/" .. folder .. "/", 1, true) then
				local id = api.res.modelRep.find(n)
				local _, other = CC.modelLoads(id)
				local av = api.res.modelRep.get(id).metadata.availability
				local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
				local y = CC.year()
				if other > 0 and from <= y and (to == 0 or to > y) and (not model or from > model.from) then model = { id = id, name = n, from = from } end
			end
		end)
	end
	if not model then return { ok = false, error = "nessun veicolo '" .. folder .. "' disponibile quest'anno", line_id = li.line, log = log } end
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(10, a.num_vehicles or 2)), li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, vehicles = v.vehicles,
		model = model.name, errors = v.errors, log = log }
end

-- ---------------------------------------------------------------- superstrade tra citta'
-- Riusa il costruttore di binari (curva, profilo, ponti, gallerie) con un tipo di strada al posto del binario e
-- TUTTI gli incroci a livelli separati (CC.MIN_CROSS_ANGLE = 91 -> ogni incrocio diventa sovrappasso/sottopasso).
-- Usa CC.CURVE_SEG_TYPE e CC.CURVE_ROAD_TYPE, aggiunti a buildCurvedTrack in cc_lib (se non impostati: binario
-- come prima). Collega due nodi di strada ai margini delle citta' (niente svincoli per ora).
local function highwayTemplate()
	if CC.HIGHWAY_TEMPLATE then return CC.HIGHWAY_TEMPLATE end
	local best
	for _, n in ipairs(CC.each(api.res.streetTemplateRep.getAll())) do
		local s = tostring(n)
		if (s:find("highway") or s:find("motorway")) and not s:find("one_way") and not s:find("/track/") then best = best or s end
	end
	return best
end

-- Estremo stradale ai margini della citta' verso un punto (capolinea o nodo di una strada verso l'esterno).
local function townRoadEnd(town, toward)
	local c = CC.posOf(town)
	local dx, dy = unit2(toward.x - c.x, toward.y - c.y)
	local best, bs
	for _, d in ipairs(CC.deadEndsNear(c.x + dx * 400, c.y + dy * 400, 700)) do
		local v = (d.x - c.x) * dx + (d.y - c.y) * dy
		if not bs or v > bs then best, bs = d, v end
	end
	if not best then return nil end
	local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(best.node))
	local be = CC.comp(segs[1], api.type.ComponentType.BASE_EDGE)
	local first = be.node0 == best.node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local tx, ty = t.x, t.y
	if first then tx, ty = -tx, -ty end
	tx, ty = unit2(tx, ty)
	return { node = best.node, x = p.x, y = p.y, z = p.z, dx = tx, dy = ty }
end

SIM_ACTIONS.build_highway = function(a)
	CC.need(a, { town_ids = "ints" })
	if #a.town_ids ~= 2 then return { ok = false, error = "per ora una superstrada collega esattamente 2 citta'" } end
	local tmpl = highwayTemplate()
	if not tmpl then return { ok = false, error = "tipo di strada per superstrade non trovato (vedi sonda s5)" } end
	local c1, c2 = CC.posOf(a.town_ids[1]), CC.posOf(a.town_ids[2])
	local e1, e2 = townRoadEnd(a.town_ids[1], c2), townRoadEnd(a.town_ids[2], c1)
	if not e1 or not e2 then return { ok = false, error = "nessuna strada di uscita adatta ai margini delle citta'" } end
	local saved = { CC.trackTemplate, CC.MIN_CROSS_ANGLE, CC.CURVE_SEG_TYPE, CC.CURVE_ROAD_TYPE }
	CC.trackTemplate = function() return tmpl end
	CC.MIN_CROSS_ANGLE = 91
	CC.CURVE_SEG_TYPE = 0
	CC.CURVE_ROAD_TYPE = api.type.enum.RoadType.STREET
	local log = {}
	local ok, info
	for _, kf in ipairs({ 0.9, 0.5, 1.4 }) do
		-- in pcall: anche se qualcosa va storto le impostazioni del binario vengono ripristinate qui sotto
		local okP, r1, r2 = pcall(CC.buildCurvedTrack, e1, e2, 80, false, kf)
		if okP then ok, info = r1, r2 else ok, info = false, { error = tostring(r1) } end
		if ok or not info.retry then break end
		log[#log + 1] = tostring(info.error) .. ", provo un altro tracciato"
	end
	CC.trackTemplate, CC.MIN_CROSS_ANGLE, CC.CURVE_SEG_TYPE, CC.CURVE_ROAD_TYPE = saved[1], saved[2], saved[3], saved[4]
	if not ok then return { ok = false, error = tostring(info.error), log = log } end
	return { ok = true, template = tmpl, length = info.length, bridges = info.bridges, tunnels = info.tunnels,
		overpasses = info.overpasses, underpasses = info.underpasses, log = log }
end
-- ===================================================================== fine b4

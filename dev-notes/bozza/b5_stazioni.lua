-- ===================================================================== BOZZA (NON TESTATO) - b5 stazioni e depositi
-- Dimensionamento delle stazioni ferroviarie (lunghezza in base ai treni, numero di binari in base a linee e treni,
-- binari di transito), stazioni con N binari, scelta del posto con ripieghi in caso di conflitto di spazio,
-- treni mai piu' lunghi del marciapiede, comando diretto "costruisci deposito".
-- DA VERIFICARE in gioco (sonde s10 e prova p17): lunghezza dei modelli, parametro "length" della stazione,
-- posizione dei moduli per lunghezze diverse da 160 m, stazioni con piu' di 2 binari.

CC.STATION_SEG_LEN = CC.STATION_SEG_LEN or 40       -- un pezzo di marciapiede = 40 m (4 pezzi = 160 m, verificato)
CC.DEFAULT_CAR_LEN = CC.DEFAULT_CAR_LEN or 26       -- ripiego se la lunghezza del modello non si legge
CC.DEFAULT_LOCO_LEN = CC.DEFAULT_LOCO_LEN or 22

-- ---------------------------------------------------------------- lunghezze dei treni
-- Lunghezza di un modello di veicolo (m) dal suo ingombro. DA VERIFICARE con la sonda s10: campo e asse.
function CC.modelLength(id)
	local L
	pcall(function()
		local bi = api.res.modelRep.get(id).boundingInfo
		local lx = bi.bbMax.x - bi.bbMin.x
		local ly = bi.bbMax.y - bi.bbMin.y
		L = math.max(lx, ly)                          -- il veicolo e' piu' lungo che largo: prendo il lato maggiore
	end)
	if not L or L <= 1 or L > 200 then return nil end
	return L
end

function CC.compositionLength(models)
	local tot = 0
	for i, id in ipairs(models) do
		tot = tot + (CC.modelLength(id) or (i == 1 and CC.DEFAULT_LOCO_LEN or CC.DEFAULT_CAR_LEN))
	end
	return tot
end

-- Lunghezza stimata di un treno passeggeri con nCars carrozze (modelli piu' recenti disponibili).
function CC.estimateTrainLength(nCars)
	local loco, car
	pcall(function() loco = CC.pickLocomotive(CC.railEra().catenary) end)
	pcall(function() car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true }) end)
	local L = (loco and CC.modelLength(loco.id)) or CC.DEFAULT_LOCO_LEN
	local c = (car and CC.modelLength(car.id)) or CC.DEFAULT_CAR_LEN
	return math.floor(L + c * (nCars or 3) + 0.5)
end

-- Quanti carri/carrozze entrano in un marciapiede lungo maxLen (almeno 1).
function CC.fitCars(locoId, carId, nCars, maxLen)
	if not maxLen then return nCars end
	local L = (locoId and CC.modelLength(locoId)) or CC.DEFAULT_LOCO_LEN
	local c = (carId and CC.modelLength(carId)) or CC.DEFAULT_CAR_LEN
	local fit = math.floor((maxLen - L) / c)
	return math.max(1, math.min(nCars, fit))
end

-- ---------------------------------------------------------------- piano di una stazione
-- p = { kind = "passengers" | "cargo", lines = linee che fermano, trains = treni che fermano (totale),
--       train_len = metri del treno piu' lungo, double = linea a doppio binario, through = linee che passano
--       senza fermarsi (> 0: binari di transito), terminal = capolinea, cargo_types = merci diverse (scali),
--       max_tracks = limite (default 8) }
-- Ritorna { segments, length, tracks, through, layout, notes }.
-- Regole (vedi dev-notes/note/TODO.md, "Dimensionamento delle stazioni"):
--   - lunghezza: il treno piu' lungo + 10 m di margine, a pezzi da 40 m (minimo 2 pezzi = 80 m);
--   - binario unico (1) se ferma un solo treno di una sola linea; 2 se i treni devono incrociarsi;
--     doppio binario: almeno un binario per senso; una linea in piu' = binari in piu';
--   - capolinea con 3 o piu' treni: un binario in piu' (i treni restano fermi di piu');
--   - scali merci: un binario per merce, uno in piu' se i treni sono di piu' (uno carica, l'altro arriva);
--   - binari di transito: 1 (2 con doppio binario) se ci sono linee che non fermano.
function CC.planStation(p)
	p = p or {}
	local seg = CC.STATION_SEG_LEN
	local trainLen = p.train_len or 120
	local segments = math.max(2, math.min(12, math.ceil((trainLen + 10) / seg)))
	local trains = math.max(1, p.trains or 1)
	local lines = math.max(1, p.lines or 1)
	local tracks, notes = 1, {}
	if p.kind == "cargo" then
		-- VERIFICATO solo lo scalo a 1 binario da 160 m (copiato da uno fatto a mano): i treni merci restano entro 150 m
		-- e gli altri treni aspettano fuori stazione (binario d'attesa). Merci diverse: vagoni misti sullo stesso binario.
		tracks = 1
		segments = 4
		if trains > 1 then notes[#notes + 1] = "scalo a 1 binario: gli altri treni aspettano fuori stazione (serve un binario d'attesa)" end
		if (p.cargo_types or 1) > 1 then notes[#notes + 1] = "merci diverse sullo stesso binario (scalo universale)" end
		if trainLen > 150 then notes[#notes + 1] = "treno accorciato a 150 m (scalo da 160 m)" end
	elseif p.double then
		tracks = math.max(2, 2 * math.ceil(lines / 2))
		if trains > 2 * tracks then tracks = tracks + 2 end
	else
		if trains <= 1 and lines <= 1 then
			tracks = 1
			notes[#notes + 1] = "binario unico: un solo treno, nessun incrocio"
		else
			tracks = 2
		end
		if lines >= 2 then tracks = math.max(tracks, lines) end
	end
	if p.terminal and p.kind ~= "cargo" and trains >= 3 then tracks = tracks + 1 end
	local through = 0
	if (p.through or 0) > 0 then through = p.double and 2 or 1 end
	local maxT = p.max_tracks or 8
	if tracks + through > maxT then
		notes[#notes + 1] = "binari ridotti al massimo di " .. maxT
		through = math.max(0, math.min(through, maxT - tracks))
		tracks = math.min(tracks, maxT - through)
	end
	return { segments = segments, length = segments * seg, tracks = tracks, through = through,
		layout = CC.stationLayout(tracks, through), kind = p.kind or "passengers", notes = notes }
end

-- Disposizione delle colonne della stazione: "P" marciapiede, "T" binario. Ogni binario ha un marciapiede accanto
-- (marciapiedi a isola tra due binari): 1 -> "PT" (come la stazione copiata nel gioco), 2 -> "PTTP",
-- 3 -> "PTTPTP", 4 -> "PTTPTTP". I binari di transito sono binari in piu': un treno che non ferma passa su un
-- binario libero qualsiasi (le fermate le decide la linea, non il binario).
function CC.stationLayout(tracks, through)
	local k = math.max(1, tracks or 1) + math.max(0, through or 0)
	if k == 1 then return "PT" end
	local s = "P"
	for i = 1, k do
		s = s .. "T"
		if i % 2 == 0 then s = s .. "P" end
	end
	if k % 2 == 1 then s = s .. "P" end
	return s
end

-- Posizioni (in unita' del gioco, 10 = un pezzo da 40 m) dei pezzi lungo la stazione.
-- Verificato solo per 4 pezzi: -10, 0, 10, 20. Per n pezzi si estende allo stesso modo. DA VERIFICARE (s10).
function CC.moduleOffsets(segments)
	local start = -10 * math.floor((segments - 1) / 2)
	local out = {}
	for k = 1, segments do out[k] = start + 10 * (k - 1) end
	return out
end

-- Parametro "length" della stazione modulare. Verificato solo 3 -> 160 m (4 pezzi). DA VERIFICARE (s10).
function CC.stationLengthParam(segments)
	if CC.STATION_LENGTH_PARAMS and CC.STATION_LENGTH_PARAMS[segments] then return CC.STATION_LENGTH_PARAMS[segments] end
	return math.max(0, segments - 1)
end

-- Modulo marciapiede merci (dal modello copiato con la sonda s6 o cercato tra i moduli).
function CC.cargoPlatformModule(e)
	e = e or CC.railEra()
	if CC.CARGO_PLATFORM_MODULE then return CC.CARGO_PLATFORM_MODULE end
	local all = {}
	pcall(function() for _, n in ipairs(CC.each(api.res.moduleRep.getAll())) do all[tostring(n)] = true end end)
	local M = "::/stations/rail/modular_station/"
	for _, cand in ipairs({ M .. "platform_cargo_era_" .. e.era .. ".module", M .. "platform_cargo.module", M .. "cargo_platform_era_" .. e.era .. ".module" }) do
		if all[cand] then return cand end
	end
	for n in pairs(all) do
		if n:find("modular_station", 1, true) and n:find("cargo", 1, true) and n:find("platform", 1, true) then return n end
	end
	return nil
end

-- Moduli della stazione per una disposizione qualsiasi (stesso schema degli slot della stazione da 160 m copiata
-- nel gioco: 84xxxxx binari, 74xxxxx marciapiedi, 104xxxxx tettoie, 340xxxx edifici, 108xxxxx scale).
function CC.railStationModulesN(e, layout, segments, kind)
	e = e or CC.railEra()
	local M = "::/stations/rail/modular_station/"
	local tr = CC.trackOverride or e.track
	local T = "::/trainstation___/infrastructure/track/" .. tr .. "/" .. tr .. (e.catenary and "_catenary" or "") .. ".street_template"
	local era = "_era_" .. e.era
	local cargo = kind == "cargo"
	-- VERIFICATO (4 crash del 07.10.2026): il marciapiede merci e' largo DUE colonne e usa gli slot 64xxxxx (non 74xxxxx).
	-- Messo come un marciapiede passeggeri (74xxxxx, binario nella colonna accanto) si sovrappone al binario e genera
	-- tratti doppi sotto i marciapiedi ("Duplicate edges found", quota -6 m): il gioco va in crash.
	-- Schema copiato da 3 scali costruiti a mano (sonda s22): 1 binario, 160 m (length = 3), specialization = 1:
	--   3701980 main_building_1_cargo, 64000xx marciapiede merci (colonna 0), 84020xx binario (colonna 2), xx = -10..20.
	-- Solo questo schema e' verificato: altre lunghezze o piu' binari vanno prima copiati da uno scalo fatto a mano.
	if cargo then
		if layout ~= "PT" or segments ~= 4 then
			return nil, "scalo merci: verificato solo con 1 binario e 160 m (chiesti " .. CC.layoutTracks(layout) .. " binari, " .. (segments * CC.STATION_SEG_LEN) .. " m)"
		end
		local platC = CC.cargoPlatformModule(e)
		if not platC then return nil, "modulo marciapiede merci non trovato" end
		local mods = { [3701980] = { name = M .. "main_building_1_cargo.module", variant = 0 } }
		for _, o in ipairs(CC.moduleOffsets(4)) do
			mods[6400000 + o] = { name = platC, variant = 0 }
			mods[8402000 + o] = { name = T, variant = 0 }
		end
		return mods, nil, { specialization = 1 }
	end
	local plat = M .. "platform_passenger" .. era .. ".module"
	local mods = {}
	do
		mods[3400020] = M .. "main_building_1" .. era .. ".module"
		if segments >= 4 then
			mods[3400005] = M .. "side_building_1" .. era .. ".module"
			mods[3400035] = M .. "side_building_1" .. era .. ".module"
		end
		mods[10800000] = M .. "addon_platform_passenger_stairs" .. era .. ".module"
	end
	for _, o in ipairs(CC.moduleOffsets(segments)) do
		for c = 0, #layout - 1 do
			local ch = layout:sub(c + 1, c + 1)
			if ch == "T" then
				mods[8400000 + c * 1000 + o] = T
			else
				mods[7400000 + c * 1000 + o] = plat
				mods[10400000 + c * 1000 + o] = M .. "platform_passenger_roof" .. era .. ".module"
			end
		end
	end
	local out = {}
	for k, v in pairs(mods) do out[k] = { name = v, variant = 0 } end
	return out
end

function CC.layoutTracks(layout)
	local n = 0
	for _ in layout:gmatch("T") do n = n + 1 end
	return n
end

-- Estremo libero di un binario: nodo, posizione e direzione verso l'esterno (nil se il nodo non e' un estremo).
function CC.trackEndInfo(node)
	local segs = CC.each(api.engine.system.streetSystem.getNodeSegments(node))
	if #segs ~= 1 then return nil end
	local be = CC.comp(segs[1], api.type.ComponentType.BASE_EDGE)
	if not be then return nil end
	local first = be.node0 == node
	local p = first and be.position0 or be.position1
	local t = first and be.tangent0 or be.tangent1
	local tx, ty = t.x, t.y
	if first then tx, ty = -tx, -ty end
	local tl = math.sqrt(tx * tx + ty * ty)
	if tl < 1e-6 then return nil end
	return { node = node, x = p.x, y = p.y, z = p.z, dx = tx / tl, dy = ty / tl, edge = segs[1] }
end

-- Unisce gli estremi (paralleli, stessa direzione) in uno solo con una serie di scambi ("scala").
-- ends ordinati di lato; il primo prosegue dritto, gli altri lo raggiungono uno alla volta (CC.buildThroat).
function CC.mergeEnds(ends, L)
	if #ends == 1 then return true, { endInfo = ends[1], edges = {} } end
	local cur, edges = ends[1], {}
	for i = 2, #ends do
		local okT, T = CC.buildThroat(cur, ends[i], L)
		if not okT then return false, { error = tostring(T.error), edges = edges } end
		for _, e in ipairs(T.edges) do edges[#edges + 1] = e end
		cur = T.endInfo
	end
	return true, { endInfo = cur, edges = edges }
end

-- Stazione ferroviaria con disposizione qualsiasi.
-- opts = { layout = "PTTP", segments = 4, kind = "passengers" | "cargo", name, merge = { f = true, b = true } }
-- merge.f / merge.b: unire i binari in un solo estremo verso +d (f) o verso -d (b). Senza unione restano tutti gli
-- estremi di quel lato (servono per il doppio binario o per un deposito accanto alla linea).
-- Ritorna ok, { construction, station, group, ends, sides = { f = {...}, b = {...} }, edges, tracks, length }
function CC.buildRailStationN(cx, cy, dx, dy, opts)
	opts = opts or {}
	local CT = api.type.ComponentType
	local l = math.sqrt(dx * dx + dy * dy); dx, dy = dx / l, dy / l
	local layout = opts.layout or "PTTP"
	local segments = opts.segments or 4
	local nT = CC.layoutTracks(layout)
	local merge = opts.merge or { f = true, b = true }
	local mods, merr, extra = CC.railStationModulesN(nil, layout, segments, opts.kind)
	if not mods then return false, { error = merr } end
	local z = opts.z or CC.heightAt(cx, cy) or 0
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = "::/stations/rail/modular_station/modular_station.con"
	ce.params = { year = CC.year(), seed = 0, modules = mods, tracks = nT, length = CC.stationLengthParam(segments) }
	for k, v in pairs(extra or {}) do ce.params[k] = v end
	ce.transf = api.type.Mat4f.new(
		api.type.Vec4f.new(dy, -dx, 0, 0), api.type.Vec4f.new(dx, dy, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(cx, cy, z, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	ce.name = opts.name or "Stazione"
	prop.constructionsToAdd = { ce }
	local okc, cmd = CC.buildCmd(prop, false)
	if not okc then return false, { error = tostring(cmd) } end
	local ok, res, ents = CC.send(cmd)
	if not ok then return false, { error = "stazione rifiutata" } end
	local con
	for _, e in ipairs(ents or {}) do
		local c = CC.comp(e, CT.CONSTRUCTION)
		if c and #CC.each(c.stations) > 0 then con = e end
	end
	if not con then return false, { error = "stazione non trovata dopo la costruzione" } end
	local c = CC.comp(con, CT.CONSTRUCTION)
	local st = CC.each(c.stations)[1]
	local okG, g = pcall(api.engine.system.stationGroupSystem.getStationGroup, st)
	if opts.name and okG then pcall(function() api.cmd.sendCommand(api.cmd.makeSetNameCmd(g, opts.name)) end) end
	local raw = CC.railStationEnds(con)
	if #raw ~= 2 * nT then
		return false, { error = "la stazione ha " .. #raw .. " estremi invece di " .. (2 * nT), construction = con }
	end
	local nx, ny = -dy, dx
	local sides = { f = {}, b = {} }
	for _, en in ipairs(raw) do
		local key = (en.dx * dx + en.dy * dy) > 0 and "f" or "b"
		table.insert(sides[key], en)
	end
	local edges, ends = {}, {}
	local thLen = CC.THROAT_LEN or ((CC.trackOverride or CC.railEra().track) == "simple" and 80 or 160)
	for _, key in ipairs({ "f", "b" }) do
		local list = sides[key]
		if #list ~= nT then
			CC.removeConstruction(con)
			return false, { error = "estremi della stazione non riconosciuti (" .. key .. ": " .. #list .. ")" }
		end
		table.sort(list, function(p, q) return (p.x * nx + p.y * ny) < (q.x * nx + q.y * ny) end)
		if merge[key] and nT > 1 then
			local okM, Mi = CC.mergeEnds(list, thLen)
			for _, e in ipairs(Mi.edges or {}) do edges[#edges + 1] = e end
			if not okM then
				CC.safeRemove(con, edges)
				return false, { error = "scambi della stazione rifiutati: " .. tostring(Mi.error) }
			end
			sides[key] = { Mi.endInfo }
		end
		for _, en in ipairs(sides[key]) do ends[#ends + 1] = en end
	end
	return true, { construction = con, station = st, group = okG and g or nil, ends = ends, sides = sides, edges = edges,
		tracks = nT, layout = layout, length = segments * CC.STATION_SEG_LEN }
end

function CC.expectedEnds(plan, merge)
	merge = merge or { f = true, b = true }
	local nT = CC.layoutTracks(plan.layout)
	local n = 0
	for _, k in ipairs({ "f", "b" }) do n = n + ((merge[k] or nT == 1) and 1 or nT) end
	return n
end

-- Stazione ferroviaria del giocatore entro r metri (per riusarla invece di costruirne un'altra accanto).
function CC.playerRailStationNear(x, y, r)
	local best, bd
	for g in pairs(CC.playerGroups()) do
		local p = CC.posOf(g)
		if p then
			local d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
			if d < r and (not bd or d < bd) then
				local rail = false
				pcall(function()
					local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
					for _, cr in ipairs(CC.each(car[1])) do if cr == api.type.enum.Carrier.RAIL then rail = true end end
				end)
				if rail then best, bd = g, d end
			end
		end
	end
	return best, bd
end

-- ---------------------------------------------------------------- posto della stazione con ripieghi
-- Prova in ordine (dal meno al piu' invasivo, vedi TODO "Conflitti di spazio"):
--   1. il piano completo, nei posti vicini e con orientamenti diversi (CC.placeRailStation);
--   2. posti piu' lontani dal centro (serve poi la navetta);
--   3. stazione piu' corta (treni piu' corti);
--   4. meno binari (gli incroci/sorpassi si fanno fuori stazione);
--   5. riuso di una stazione del giocatore vicina.
-- Non demolisce mai edifici: se nulla va, ritorna le alternative da proporre all'utente.
-- opts: score, accept, merge, min_segments, min_tracks, Rs. Ritorna info (o nil), { plan, steps, needs_feeder, shorter, ... }
function CC.placeStationSmart(center, dx, dy, nbs, name, plan, opts)
	opts = opts or {}
	local steps, budget = {}, opts.budget or 30
	local function copyPlan(p, changes)
		local q = {}
		for k, v in pairs(p) do q[k] = v end
		for k, v in pairs(changes or {}) do q[k] = v end
		q.layout = CC.stationLayout(q.tracks, q.through)
		q.length = q.segments * CC.STATION_SEG_LEN
		return q
	end
	local function attempt(label, p, Rs, tries)
		if budget <= 0 then steps[#steps + 1] = { step = label, ok = false, reasons = { "troppi tentativi" } }; return nil end
		local n = math.min(tries or 6, budget)
		budget = budget - n
		local st, why = CC.placeRailStation(center, dx, dy, nbs, name, {
			score = opts.score, accept = opts.accept, Rs = Rs or opts.Rs, maxTries = n,
			expectEnds = CC.expectedEnds(p, opts.merge),
			builder = function(x, y, ddx, ddy)
				return CC.buildRailStationN(x, y, ddx, ddy, { layout = p.layout, segments = p.segments, kind = p.kind, name = name, merge = opts.merge })
			end,
		})
		steps[#steps + 1] = { step = label, ok = st ~= nil, reasons = why }
		return st
	end
	local st = attempt("piano completo (" .. plan.tracks .. " binari, " .. plan.length .. " m)", plan, nil, 8)
	if st then return st, { plan = plan, steps = steps } end
	st = attempt("posti piu' lontani dal centro", plan, { 1000, 1300, 1600 }, 6)
	if st then return st, { plan = plan, steps = steps, needs_feeder = true } end
	for s = plan.segments - 1, math.max(2, opts.min_segments or 2), -1 do
		local p2 = copyPlan(plan, { segments = s })
		st = attempt("stazione piu' corta (" .. p2.length .. " m)", p2, nil, 4)
		if st then return st, { plan = p2, steps = steps, shorter = true, max_train_len = p2.length - 10 } end
	end
	for t = plan.tracks - 1, math.max(1, opts.min_tracks or 1), -1 do
		local p2 = copyPlan(plan, { tracks = t, through = 0 })
		st = attempt("meno binari (" .. t .. ")", p2, nil, 4)
		if st then return st, { plan = p2, steps = steps, fewer_tracks = true, note = "incroci e sorpassi vanno fatti fuori stazione" } end
	end
	local g = CC.playerRailStationNear(center.x, center.y, 900)
	if g then return nil, { steps = steps, reuse_group = g, message = "c'e' gia' una stazione del giocatore vicina: conviene usarla" } end
	return nil, { steps = steps, alternatives = {
		"stazione fuori citta' con navetta bus o tram verso il centro",
		"treni piu' corti con stazione piu' corta",
		"demolire alcuni edifici (solo se l'utente lo conferma)",
		"percorso diverso o citta' diversa",
	} }
end

-- ---------------------------------------------------------------- treni della giusta lunghezza
-- Fermata da cui far partire il k-esimo di n veicoli su una linea con nStops fermate (distribuiti lungo la linea).
function CC.staggerStop(k, n, nStops)
	if not nStops or nStops <= 1 or n <= 1 then return 0 end
	return math.floor((k - 1) * nStops / n) % nStops
end

-- Treno passeggeri (locomotiva + carrozze) mai piu' lungo di maxLen, assegnato alla linea dalla fermata stopIndex.
function CC.buyPassengerTrain(depot, line, nCars, stopIndex, maxLen, loco)
	loco = loco or CC.pickLocomotive(CC.railEra().catenary)
	local car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true })
	if not loco or not car then return false, { error = "nessun treno/carrozza disponibile" } end
	local n = CC.fitCars(loco.id, car.id, nCars or 3, maxLen)
	local models = { loco.id }
	for _ = 1, n do models[#models + 1] = car.id end
	local ok, veh, warn = CC.buyComposition(depot, models, line, stopIndex or 0)
	if not ok then return false, { error = tostring(veh) } end
	return true, { vehicle = veh, cars = n, warning = warn }
end

-- ---------------------------------------------------------------- depositi
-- Estremi liberi di binario (fuori dalle costruzioni e delle stazioni) entro r metri.
function CC.freeTrackEndsNear(x, y, r)
	local CT = api.type.ComponentType
	local out, seen = {}, {}
	pcall(function()
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, CT.BASE_EDGE))) do
			local be = CC.comp(e, CT.BASE_EDGE)
			if be and tostring(be.roadTemplate):find("/track/", 1, true) then
				for _, n in ipairs({ be.node0, be.node1 }) do
					if not seen[n] then
						seen[n] = true
						local info = CC.trackEndInfo(n)
						if info then info.d = math.sqrt((info.x - x) ^ 2 + (info.y - y) ^ 2); out[#out + 1] = info end
					end
				end
			end
		end
	end)
	table.sort(out, function(a, b) return a.d < b.d end)
	return out
end

-- Punto spostato "fuori dal centro": da p, lontano dal centro della citta' di d metri.
local function awayFromCenter(p, town, d)
	local c = town and CC.posOf(town)
	if not c then return p.x, p.y end
	local vx, vy = p.x - c.x, p.y - c.y
	local l = math.sqrt(vx * vx + vy * vy)
	if l < 1 then return p.x, p.y end
	return p.x + vx / l * d, p.y + vy / l * d
end

-- Costruisci deposito: kind = road | tram | rail | water. Vicino a una stazione (station_id) o a una citta' (town_id).
-- Strada/tram: capolinea di strada vicino, spostato verso l'esterno della citta'; deve raggiungere la stazione.
-- Ferrovia: su un estremo libero di binario vicino alla stazione (il piu' lontano dal centro).
-- Acqua: con lo schema copiato in gioco (CC.TEMPLATES.water_depot, sonda s6). Aerei/elicotteri: DA VERIFICARE se
-- serve un deposito (l'aeroporto potrebbe fare da hangar).
SIM_ACTIONS.build_depot = function(a)
	CC.need(a, { kind = "str", station_id = "id?", town_id = "id?", name = "str?" })
	local TM = api.type.enum.TransportMode
	local kind = a.kind
	local p = (a.station_id and CC.posOf(a.station_id)) or (a.town_id and CC.posOf(a.town_id))
	if not p then return { ok = false, error = "indica station_id o town_id" } end
	local town = a.town_id
	if not town and a.station_id then
		pcall(function() town = api.engine.system.stationSystem.getTown(CC.groupStation(a.station_id)) end)
		if town and town < 0 then town = nil end
	end
	local name = a.name or ("Deposito " .. (CC.nameOf(town or a.station_id) or ""))
	if kind == "road" or kind == "tram" then
		local x, y = awayFromCenter(p, town, 150)
		local ok, info = CC.buildDepotNear(x, y, kind, name, 900)
		if not ok then return { ok = false, error = tostring(info.error) } end
		local modes = kind == "tram" and { TM.TRAM, TM.ELECTRIC_TRAM } or { TM.BUS, TM.TRUCK }
		local reach = true
		if a.station_id then
			reach = false
			for _, n in ipairs(CC.groupNodes(a.station_id)) do
				if CC.hasPath(CC.depotNodes(info.depot), n, modes) then reach = true; break end
			end
		end
		return { ok = reach, depot_id = info.depot, error = (not reach) and "deposito costruito ma non raggiunge la stazione" or nil }
	elseif kind == "rail" then
		local cands = CC.freeTrackEndsNear(p.x, p.y, 500)
		local c = town and CC.posOf(town)
		if c then
			for _, e in ipairs(cands) do e.score = math.sqrt((e.x - c.x) ^ 2 + (e.y - c.y) ^ 2) - e.d * 0.5 end
			table.sort(cands, function(u, v) return u.score > v.score end)
		end
		local errs = {}
		for i = 1, math.min(4, #cands) do
			local okD, D = CC.depotAtEndSafe(cands[i], name, nil, {})
			if okD then return { ok = true, depot_id = D.depot } end
			errs[#errs + 1] = CC.errText(D)
			if D.construction then CC.removeConstruction(D.construction) end
		end
		-- nessun estremo libero o tutti rifiutati: deposito su una diramazione corta
		local blog = {}
		local okB, B = CC.railDepotByBranch(p, name, nil, blog)
		if okB then return { ok = true, depot_id = B.depot, log = blog } end
		return { ok = false, error = (#cands == 0 and "nessun estremo di binario libero" or table.concat(errs, "; ")) .. "; " .. table.concat(blog, "; ") }
	elseif kind == "water" then
		if not (CC.TEMPLATES and CC.TEMPLATES.water_depot) then
			return { ok = false, error = "schema del deposito navale non ancora copiato (sonda s6 su un deposito fatto a mano)" }
		end
		local okT, info = CC.buildTemplateNear("water_depot", town or a.station_id, name)
		return { ok = okT, depot = info, error = (not okT) and tostring(info) or nil }
	end
	return { ok = false, error = "tipo di deposito non gestito: " .. tostring(kind) .. " (aerei/elicotteri: da verificare se serve)" }
end
-- ===================================================================== fine b5

-- ===================================================================== BOZZA (NON TESTATO) - b2 rete
-- Azioni nuove: bus tra citta', navetta stazione-centro, aggiungi/togli/sostituisci veicoli, allunga/cancella
-- linea, annulla. Usa b1 e le funzioni gia' verificate di cc_lib/cc_actions.

-- Fermata stradale nel centro di una citta': riusa quella del giocatore piu' vicina (entro reuseR) o ne costruisce una.
function CC.townStop(town, name, reuseR)
	local c = CC.posOf(town)
	if not c then return nil, "citta' " .. tostring(town) .. " non trovata" end
	local g = CC.playerStopNear(c.x, c.y, reuseR or 250, true)
	if g then return g, nil, false end
	local ok, info = CC.buildStopNear(c.x, c.y, name, { radius = 350, avoid = playerStopsNear(c.x, c.y, 300), spacing = 100 })
	if not ok then return nil, "fermata a " .. (CC.nameOf(town) or "?") .. ": " .. tostring(info.error) end
	return info.group, nil, true
end

-- ---------------------------------------------------------------- bus tra citta'
SIM_ACTIONS.build_intercity_bus = function(a)
	CC.need(a, { town_ids = "ints", num_vehicles = "int?", name = "str?" })
	local TM = api.type.enum.TransportMode
	local towns = a.town_ids
	if #towns < 2 then return { ok = false, error = "servono almeno 2 citta'" } end
	local groups, log = {}, {}
	for i, t in ipairs(towns) do
		local g, err, built = CC.townStop(t, (CC.nameOf(t) or "Citta'") .. " autolinee", 250)
		if not g then return { ok = false, error = err, stations = groups, log = log } end
		log[#log + 1] = (CC.nameOf(t) or "?") .. ": " .. (built and "fermata nuova" or "fermata esistente riusata")
		groups[i] = g
	end
	-- strada percorribile in tutti e due i versi tra fermate consecutive (e dall'ultima alla prima)
	for i = 1, #groups do
		local g1, g2 = groups[i], groups[i % #groups + 1]
		if not CC.groupPath(g1, g2, { TM.BUS }) then
			return { ok = false, error = "nessuna strada per bus tra " .. (CC.nameOf(towns[i]) or "?") .. " e " .. (CC.nameOf(towns[i % #towns + 1]) or "?"), stations = groups, log = log }
		end
	end
	local p = CC.posOf(groups[1])
	local depot, builtD = ensureRoadDepot(groups[1], p.x, p.y, "Deposito " .. (CC.nameOf(towns[1]) or ""))
	local names = {}
	for _, t in ipairs(towns) do names[#names + 1] = CC.nameOf(t) or "?" end
	local okL, li = CC.createLine(a.name or ("Bus " .. table.concat(names, " - ")), groups)
	if not okL then return { ok = false, error = li.error, stations = groups, depot_id = depot, log = log } end
	local model = CC.pickModel("bus", nil, { passengers = true })
	if not model then return { ok = false, error = "nessun bus disponibile quest'anno", line_id = li.line } end
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(10, a.num_vehicles or 2)), li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = groups, depot_id = depot, depot_built = builtD,
		vehicles = v.vehicles, model = model.name, errors = v.errors, log = log }
end

-- ---------------------------------------------------------------- navetta stazione - centro (nodo di scambio)
-- Fermata bus accanto alla stazione (o una gia' esistente) + fermata in centro + linea con bus.
SIM_ACTIONS.connect_station_to_town = function(a)
	CC.need(a, { station_id = "int", town_id = "int?", num_vehicles = "int?" })
	local TM = api.type.enum.TransportMode
	local sp = CC.posOf(a.station_id)
	if not sp then return { ok = false, error = "stazione " .. tostring(a.station_id) .. " non trovata" } end
	local town = a.town_id
	if not town then
		pcall(function() town = api.engine.system.stationSystem.getTown(CC.groupStation(a.station_id)) end)
	end
	if not town or town < 0 then return { ok = false, error = "non so a quale citta' collegare la stazione: indica town_id" } end
	local log = {}
	-- fermata vicino alla stazione: esistente entro 150 m, altrimenti nuova
	local gS = CC.playerStopNear(sp.x, sp.y, 150, true)
	if gS == a.station_id then gS = nil end
	if not gS then
		local ok, info = CC.buildStopNear(sp.x, sp.y, (CC.nameOf(a.station_id) or "Stazione") .. " bus", { radius = 250, avoid = {}, spacing = 60 })
		if not ok then return { ok = false, error = "nessuna strada vicino alla stazione per la fermata bus: " .. tostring(info.error) } end
		gS = info.group
		log[#log + 1] = "fermata bus nuova vicino alla stazione"
	else
		log[#log + 1] = "fermata bus esistente vicino alla stazione"
	end
	local gC, err = CC.townStop(town, (CC.nameOf(town) or "Centro") .. " centro", 250)
	if not gC then return { ok = false, error = err, log = log } end
	if gC == gS then return { ok = false, error = "la stazione e' gia' in centro: navetta non necessaria", log = log } end
	if not CC.groupPath(gS, gC, { TM.BUS }) or not CC.groupPath(gC, gS, { TM.BUS }) then
		return { ok = false, error = "la fermata della stazione non e' collegata al centro su strada (andata e ritorno)", log = log }
	end
	local depot, builtD = ensureRoadDepot(gS, sp.x, sp.y, "Deposito " .. (CC.nameOf(town) or ""))
	local okL, li = CC.createLine("Navetta " .. (CC.nameOf(town) or "") .. " stazione", { gS, gC })
	if not okL then return { ok = false, error = li.error, log = log } end
	local model = CC.pickModel("bus", nil, { passengers = true })
	local okV, v = CC.buyVehicles(depot, model.id, math.max(1, math.min(6, a.num_vehicles or 2)), li.line)
	return { ok = okV and #v.errors == 0, line_id = li.line, stations = { gS, gC }, depot_id = depot, depot_built = builtD,
		vehicles = v.vehicles, errors = v.errors, log = log }
end

-- ---------------------------------------------------------------- veicoli di una linea
-- Aggiunge veicoli uguali a quelli gia' presenti sulla linea (stessa composizione).
SIM_ACTIONS.add_vehicles = function(a)
	CC.need(a, { line_id = "int", count = "int" })
	local vs = CC.lineVehicles(a.line_id)
	if #vs == 0 then return { ok = false, error = "la linea non ha veicoli da copiare: usa buy_and_assign_vehicles" } end
	local models = CC.vehicleModels(vs[1])
	if #models == 0 then return { ok = false, error = "composizione del veicolo non leggibile" } end
	local depot = CC.depotForLine(a.line_id)
	if not depot then return { ok = false, error = "nessun deposito raggiunge la linea" } end
	local nStops = math.max(1, #(CC.lineGroups(a.line_id) or {}))
	local bought, errs = {}, {}
	for i = 1, math.max(1, math.min(20, a.count)) do
		local ok, veh, warn = CC.buyComposition(depot, models, a.line_id, (#vs + i - 1) % nStops)
		if ok then bought[#bought + 1] = veh; if warn then errs[#errs + 1] = warn end else errs[#errs + 1] = veh; break end
	end
	return { ok = #bought > 0 and #errs == 0, vehicles = bought, errors = errs, depot_id = depot }
end

-- Vende gli ultimi `count` veicoli della linea (almeno uno resta, salva all=true).
SIM_ACTIONS.remove_vehicles = function(a)
	CC.need(a, { line_id = "int", count = "int" })
	local vs = CC.lineVehicles(a.line_id)
	local keep = a.all and 0 or 1
	local n = math.min(a.count, #vs - keep)
	if n <= 0 then return { ok = false, error = "sulla linea ci sono " .. #vs .. " veicoli: non ne tolgo (ne resta almeno uno)" } end
	local list = {}
	for i = #vs - n + 1, #vs do list[#list + 1] = vs[i] end
	local sold, errs = CC.sellVehicles(list)
	return { ok = sold == n, sold = sold, left = #vs - sold, errors = errs }
end

-- Modello nuovo per un pezzo di veicolo: stesso tipo (cartella), il piu' recente adatto.
local function newerModel(oldId, catenary)
	local folder = CC.modelFolder(oldId)
	local pass, other = CC.modelLoads(oldId)
	if folder == "train" then
		local hasLoad = pass > 0 or other > 0
		if hasLoad then return nil end                      -- motrici con posti (automotrici): lasciate come sono
		local loco = CC.pickLocomotive(catenary)
		return loco and loco.id
	end
	if pass > 0 then
		local excl = folder == "waggon" and { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" } or { "cargo", "wagon" }
		local m = CC.pickModel(folder, excl, { passengers = true })
		return m and m.id
	end
	local cargos = CC.modelCargoTypes(oldId)
	if #cargos > 0 then
		local m = CC.pickModelForCargo(folder, cargos[1])
		return m and m.id
	end
	return nil
end

-- Sostituisce i veicoli della linea con modelli piu' recenti (comando ufficiale makeVehicleReplaceCmd,
-- come nello script delle missioni "replace_vehicles"). DA VERIFICARE in gioco.
SIM_ACTIONS.replace_vehicles = function(a)
	CC.need(a, { line_id = "int" })
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local gt = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local modes = CC.lineModes(a.line_id)
	local electric = false
	for _, m in ipairs(modes) do if m == api.type.enum.TransportMode.ELECTRIC_TRAIN then electric = true end end
	-- i treni restano elettrici solo se la linea lo e' gia' (una linea vecchia puo' non avere la catenaria)
	local catenary = electric
	local done, same, errs = 0, 0, {}
	for _, v in ipairs(CC.lineVehicles(a.line_id)) do
		local old = CC.vehicleModels(v)
		local parts, changed = {}, false
		for i, id in ipairs(old) do
			local nid = newerModel(id, catenary) or id
			if nid ~= id then changed = true end
			local p = vu.makePart(nid, true, nil)
			p.purchaseTime = gt and math.floor(gt.gameTime) or 0
			local auto = {}
			for k = 1, math.max(1, #CC.each(p.part.compartment2loadConfig)) do auto[k] = true end
			p.autoLoadConfig = auto
			parts[i] = p
		end
		if not changed then
			same = same + 1
		else
			local cfg = api.type.TransportVehicleConfig.new()
			cfg.vehicles = parts
			local groups = {}
			for i = 1, #parts do groups[i] = 1 end
			cfg.vehicleGroups = groups
			cfg.muFileNames = {}
			local ok = CC.send(api.cmd.makeVehicleReplaceCmd(v, cfg))
			if ok then done = done + 1 else errs[#errs + 1] = "sostituzione di " .. v .. " rifiutata" end
		end
	end
	return { ok = #errs == 0, replaced = done, already_newest = same, errors = errs }
end

-- ---------------------------------------------------------------- linee
-- Cancella una linea: prima vende i veicoli (il gioco non cancella linee con veicoli), poi makeLineDestroyCmd
-- (comando usato dagli script ufficiali delle missioni). Le stazioni restano.
SIM_ACTIONS.delete_line = function(a)
	CC.need(a, { line_id = "int" })
	if not CC.comp(a.line_id, api.type.ComponentType.LINE) then return { ok = false, error = "linea inesistente" } end
	local sold, errs = CC.sellVehicles(CC.lineVehicles(a.line_id))
	local ok = CC.send(api.cmd.makeLineDestroyCmd(a.line_id))
	if not ok then errs[#errs + 1] = "cancellazione della linea rifiutata" end
	return { ok = ok, sold = sold, errors = errs }
end

-- Allunga una linea su strada fino a una citta' (fermata nuova o esistente in fondo alla linea).
-- Usa makeLineUpdateCmd(linea, componente LINE modificato): comando esistente, effetto DA VERIFICARE.
SIM_ACTIONS.extend_line = function(a)
	CC.need(a, { line_id = "int", town_id = "int" })
	local TM = api.type.enum.TransportMode
	local lc = CC.comp(a.line_id, api.type.ComponentType.LINE)
	if not lc then return { ok = false, error = "linea inesistente" } end
	local groups = CC.lineGroups(a.line_id)
	local g, err = CC.townStop(a.town_id, (CC.nameOf(a.town_id) or "Citta'") .. " fermata", 250)
	if not g then return { ok = false, error = err } end
	local modes = CC.lineModes(a.line_id)
	if #modes == 0 then modes = { TM.BUS } end
	local last, first = groups[#groups], groups[1]
	if not CC.groupPath(last, g, modes) or not CC.groupPath(g, first, modes) then
		return { ok = false, error = "la nuova fermata non e' raggiungibile dai veicoli della linea" }
	end
	local stops = {}
	for _, s in ipairs(CC.each(lc.stops)) do stops[#stops + 1] = s end
	local st = api.type.Line.Stop.new()
	st.stationGroup = g; st.station = 0; st.terminal = 0
	stops[#stops + 1] = st
	lc.stops = stops
	local ok = CC.send(api.cmd.makeLineUpdateCmd(a.line_id, lc))
	local after = CC.lineGroups(a.line_id) or {}
	return { ok = ok and #after == #groups + 1, stops_before = #groups, stops_after = #after, new_stop = g }
end

-- ---------------------------------------------------------------- annulla
-- a.created = quanto restituito da un'azione (result.created). Ordine: veicoli, linee, costruzioni, binari.
-- Le strade nuove non si toccano (possono essere strade cittadine rifatte): vengono solo elencate.
SIM_ACTIONS.undo = function(a)
	local c = a.created or {}
	local log = {}
	local sold, e1 = CC.sellVehicles(c.vehicles or {})
	log[#log + 1] = sold .. " veicoli venduti"
	-- i veicoli delle linee create (anche quelli comprati dopo) vanno venduti prima di cancellare la linea
	local nL = 0
	for _, L in ipairs(c.lines or {}) do
		if CC.comp(L, api.type.ComponentType.LINE) then
			local vs = CC.lineVehicles(L)
			if #vs > 0 then sold = sold + (CC.sellVehicles(vs) or 0) end
			if CC.send(api.cmd.makeLineDestroyCmd(L)) then nL = nL + 1 else log[#log + 1] = "linea " .. L .. " non cancellata" end
		end
	end
	log[#log + 1] = nL .. " linee cancellate"
	-- VERIFICATO (due crash del 07.10.2026): vendere veicoli e togliere il loro deposito nello stesso momento, o togliere
	-- binari e la stazione a cui sono attaccati insieme, corrompe lo stato del gioco. "Annulla" lavora a fasi, una per
	-- chiamata: 1) veicoli e linee; 2) binari; 3) costruzioni. Se resta qualcosa, risponde done = false e va richiamato.
	local existing = function(list) local o = {} for _, x in ipairs(list or {}) do if api.engine.entityExists(x) then o[#o + 1] = x end end return o end
	local tracks = existing(c.tracks)
	local cons = existing(c.constructions)
	if sold > 0 or nL > 0 then
		log[#log + 1] = "fase 1 fatta (veicoli e linee): binari e costruzioni al prossimo annulla"
		return { ok = true, done = (#tracks == 0 and #cons == 0), log = log, errors = e1 }
	end
	if #tracks > 0 then
		local okE, nE = CC.removeEdges(tracks)
		log[#log + 1] = tostring(okE and nE or 0) .. " tratti di binario rimossi; costruzioni al prossimo annulla"
		return { ok = okE ~= false, done = #cons == 0, log = log, errors = e1 }
	end
	local nC = 0
	for i = #cons, 1, -1 do
		if CC.removeConstruction(cons[i]) then nC = nC + 1 else log[#log + 1] = "costruzione " .. cons[i] .. " non rimossa" end
	end
	log[#log + 1] = nC .. " costruzioni rimosse"
	if c.roads and #c.roads > 0 then log[#log + 1] = #c.roads .. " tratti di strada lasciati (non si annullano)" end
	return { ok = true, done = true, log = log, errors = e1 }
end
-- ===================================================================== fine b2

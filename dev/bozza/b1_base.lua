-- ===================================================================== BOZZA (NON TESTATO) - b1 base
-- Va caricata DOPO cc_lib.lua e cc_actions.lua (stesso blocco: usa i loro "local", es. SIM_ACTIONS).
-- Contenuto: registro di cio' che ogni azione costruisce (per "annulla"), verifica a secco delle proposte,
-- controllo degli argomenti, funzioni comuni su linee, veicoli, depositi e bacini delle stazioni.
-- Le funzioni dell'API usate qui sono gia' verificate in gioco, salvo dove c'e' scritto DA VERIFICARE.

-- ---------------------------------------------------------------- registro delle entita' create
-- CC.send viene "avvolta": durante un'azione (registro aperto con CC.txBegin) ogni comando riuscito aggiunge al registro le
-- entita' create. Alla fine l'azione restituisce result.created = { vehicles, lines, constructions, tracks, roads },
-- che il middleware salva per poter annullare.
-- I registri si possono annidare (un'azione che ne chiama un'altra): ogni comando va in tutti quelli aperti.
CC._txStack = CC._txStack or {}
local CC_sendOrig = CC.send
function CC.send(cmd)
	local ok, res, ents = CC_sendOrig(cmd)
	if ok and #CC._txStack > 0 then
		local newE, newV = {}, {}
		for _, e in ipairs(ents or {}) do newE[#newE + 1] = e end
		pcall(function() local e = res.resultEntity; if e and e >= 0 then newE[#newE + 1] = e end end)
		pcall(function() local v = res.resultVehicleEntity; if v and v >= 0 then newV[#newV + 1] = v end end)
		for _, tx in ipairs(CC._txStack) do
			for _, e in ipairs(newE) do tx.ents[#tx.ents + 1] = e end
			for _, v in ipairs(newV) do tx.vehicles[#tx.vehicles + 1] = v end
		end
	end
	return ok, res, ents
end

function CC.txBegin() CC._txStack[#CC._txStack + 1] = { ents = {}, vehicles = {} } end
function CC.txEnd() local tx = CC._txStack[#CC._txStack]; CC._txStack[#CC._txStack] = nil; return tx end

-- Divide le entita' registrate per tipo (solo quelle che esistono ancora).
-- tracks: segmenti di binario (e di superstrada) fuori dalle costruzioni; roads: segmenti di strada nuovi (non si annullano: possono
-- essere pezzi di strade cittadine spezzate per un passaggio a livello o rifatte con i binari del tram).
function CC.txClassify(tx)
	local CT = api.type.ComponentType
	local out = { vehicles = {}, lines = {}, constructions = {}, tracks = {}, roads = {} }
	local seen = {}
	for _, v in ipairs(tx and tx.vehicles or {}) do
		if not seen[v] and api.engine.entityExists(v) then seen[v] = true; out.vehicles[#out.vehicles + 1] = v end
	end
	for _, e in ipairs(tx and tx.ents or {}) do
		if not seen[e] and api.engine.entityExists(e) then
			seen[e] = true
			if CC.comp(e, CT.LINE) then
				out.lines[#out.lines + 1] = e
			elseif CC.comp(e, CT.CONSTRUCTION) then
				out.constructions[#out.constructions + 1] = e
			elseif CC.comp(e, CT.TRANSPORT_VEHICLE) then
				out.vehicles[#out.vehicles + 1] = e
			else
				local be = CC.comp(e, CT.BASE_EDGE)
				if be and not CC.inConstruction(e) then
					local tp = tostring(be.roadTemplate)
					if tp:find("/track/", 1, true) or tp:find("highway", 1, true) or tp:find("motorway", 1, true) then out.tracks[#out.tracks + 1] = e
					else out.roads[#out.roads + 1] = e end
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- verifica a secco
-- Valuta la proposta senza costruire (makeProposalData, verificato nella diagnosi dei binari).
-- Se gia' la verifica lancia un'eccezione, la proposta NON va inviata: e' il caso che ha corrotto la partita.
function CC.dryRun(prop)
	local okP, pd = pcall(api.engine.util.proposal.makeProposalData, prop, nil)
	if not okP then return false, { exception = tostring(pd):sub(1, 160) } end
	local info = { critical = false, msg = {} }
	pcall(function()
		info.critical = pd.errorState.critical
		for _, m in ipairs(CC.each(pd.errorState.messages)) do info.msg[#info.msg + 1] = tostring(m) end
	end)
	return not info.critical, info
end

-- Al posto di pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignore, true): prima la verifica a secco.
-- Ritorna ok, comando (oppure false, testo dell'errore).
-- Da usare anche nel codice gia' esistente quando si unisce la bozza (sostituzione meccanica).
function CC.buildCmd(prop, ignoreErrors)
	local okD, info = CC.dryRun(prop)
	if info and info.exception then return false, "il gioco rifiuta la proposta gia' in verifica: " .. info.exception end
	if not okD and ignoreErrors ~= true then return false, "proposta non valida: " .. table.concat(info.msg or {}, "; ") end
	return pcall(api.cmd.makeWorldBuildProposalCmd, prop, nil, ignoreErrors == true, true)
end

-- ---------------------------------------------------------------- controllo argomenti nella mod
-- spec: { campo = "int" | "int?" | "ints" | "str?" | "num?" }  (? = facoltativo). Errore leggibile se non va.
function CC.need(a, spec)
	for k, t in pairs(spec) do
		local v = a[k]
		local opt = t:sub(-1) == "?"
		local base = opt and t:sub(1, -2) or t
		if v == nil then
			if not opt then error("argomento mancante: " .. k, 0) end
		elseif base == "int" or base == "num" then
			if type(v) ~= "number" then error("argomento " .. k .. ": atteso un numero", 0) end
		elseif base == "ints" then
			if type(v) ~= "table" or #v == 0 then error("argomento " .. k .. ": attesa una lista di numeri", 0) end
			for _, x in ipairs(v) do if type(x) ~= "number" then error("argomento " .. k .. ": attesa una lista di numeri", 0) end end
		elseif base == "str" then
			if type(v) ~= "string" then error("argomento " .. k .. ": atteso un testo", 0) end
		end
	end
end

-- ---------------------------------------------------------------- stato della partita
function CC.gameSpeed()
	local s
	pcall(function() s = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_SPEED).speedup end)
	return s
end

-- ---------------------------------------------------------------- linee e veicoli
function CC.lineVehicles(L)
	local out = {}
	pcall(function() out = CC.each(api.engine.system.transportVehicleSystem.getLineVehicles(L)) end)
	return out
end

function CC.lineGroups(L)
	local lc = CC.comp(L, api.type.ComponentType.LINE)
	if not lc then return nil end
	local g = {}
	for _, s in ipairs(CC.each(lc.stops)) do g[#g + 1] = s.stationGroup end
	return g
end

-- Modi di trasporto della linea (lc.vehicleInfo.transportModes: tabella di booleani con indice modo+1).
function CC.lineModes(L)
	local modes = {}
	pcall(function()
		local tm = CC.comp(L, api.type.ComponentType.LINE).vehicleInfo.transportModes
		for i = 1, 32 do
			local on = false
			pcall(function() on = tm[i] end)
			if on then modes[#modes + 1] = i - 1 end
		end
	end)
	return modes
end

-- Modelli (id) dei pezzi di un veicolo, nell'ordine (locomotiva per prima).
function CC.vehicleModels(v)
	local ids = {}
	pcall(function()
		local tv = CC.comp(v, api.type.ComponentType.TRANSPORT_VEHICLE)
		for _, p in ipairs(CC.each(tv.transportVehicleConfig.vehicles)) do ids[#ids + 1] = p.part.modelId end
	end)
	return ids
end

-- Tipi di merce (id) che un modello puo' caricare, passeggeri esclusi.
function CC.modelCargoTypes(modelId)
	local P = CC.passengerCargo()
	local set, out = {}, {}
	pcall(function()
		local tv = api.res.modelRep.get(modelId).metadata.transportVehicle
		for _, cpt in ipairs(CC.each(tv.compartments)) do
			for _, lc in ipairs(CC.each(cpt.loadConfigs)) do
				pcall(function()
					api.res.cargoTypeRep.forEachCargoType(lc.cargoEntry.cargoTypeSet, function(cid)
						if cid ~= P and not set[cid] then set[cid] = true; out[#out + 1] = cid end
					end)
				end)
			end
		end
	end)
	return out
end

-- Cartella del modello: "bus", "tram", "truck", "train", "waggon", "plane", "ship", ...
function CC.modelFolder(modelId)
	local name = ""
	pcall(function() name = api.res.modelRep.getName(modelId) end)
	return name:match("/vehicle/([^/]+)/") or "?", name
end

-- Deposito del giocatore che raggiunge la prima fermata della linea (il piu' vicino).
function CC.depotForLine(L)
	local groups = CC.lineGroups(L)
	if not groups or #groups == 0 then return nil end
	local modes = CC.lineModes(L)
	if #modes == 0 then
		-- ripiego: modi del motore del primo veicolo della linea
		local v = CC.lineVehicles(L)[1]
		local m = v and CC.vehicleModels(v)[1]
		pcall(function()
			for _, tm in ipairs(CC.each(api.res.modelRep.get(m).metadata.transportVehicle.engineTransportModes)) do modes[#modes + 1] = tm end
		end)
	end
	local p = CC.posOf(groups[1])
	local target = CC.stopNodeId(groups[1])
	local best, bd
	for _, d in ipairs(CC.playerDepots()) do
		local dist = (p and d.x) and math.sqrt((d.x - p.x) ^ 2 + (d.y - p.y) ^ 2) or 1e9
		if not bd or dist < bd then
			local dOut = CC.depotNodes(d.depot)
			if #modes > 0 and CC.hasPath(dOut, target, modes) then best, bd = d.depot, dist end
		end
	end
	return best
end

-- Compra un veicolo composto dai modelli dati (es. locomotiva + carrozze) e lo assegna alla linea.
function CC.buyComposition(depot, models, line, stopIndex)
	local vu = ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl")
	local gt = CC.comp(api.engine.util.getWorld(), api.type.ComponentType.GAME_TIME)
	local parts, groups = {}, {}
	for i, id in ipairs(models) do
		local p = vu.makePart(id, true, nil)
		p.purchaseTime = gt and math.floor(gt.gameTime) or 0
		local auto = {}
		for k = 1, math.max(1, #CC.each(p.part.compartment2loadConfig)) do auto[k] = true end
		p.autoLoadConfig = auto
		parts[i] = p
		groups[i] = 1
	end
	local cfg = api.type.TransportVehicleConfig.new()
	cfg.vehicles = parts
	cfg.vehicleGroups = groups
	cfg.muFileNames = {}
	local ok, res = CC.send(api.cmd.makeVehicleBuyCmd(api.engine.util.getPlayer(), depot, cfg))
	local veh
	pcall(function() veh = res.resultVehicleEntity end)
	if not ok or not veh or veh < 0 then return false, "acquisto fallito" end
	if line then
		local ok2 = CC.send(api.cmd.makeVehicleSetLineCmd(veh, line, stopIndex or 0))
		if not ok2 then return true, veh, "assegnazione alla linea fallita" end
	end
	return true, veh
end

function CC.sellVehicles(list)
	local sold, errs = 0, {}
	local player = api.engine.util.getPlayer()
	for _, v in ipairs(list) do
		if api.engine.entityExists(v) then
			local ok = CC.send(api.cmd.makeVehicleSellCmd({ v }, player))
			if ok then sold = sold + 1 else errs[#errs + 1] = "vendita " .. v .. " fallita" end
		end
	end
	return sold, errs
end

-- ---------------------------------------------------------------- bacino delle stazioni
-- Cosa "vede" una stazione (edifici, industrie, magazzini nel bacino). Fonte: script ufficiale delle notifiche
-- ("stazione non funzionante"): api.engine.system.catchmentAreaSystem.getStationCatchables(station, true).
function CC.stationCatchables(station)
	local list = {}
	pcall(function() list = CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(station, true)) end)
	return list
end

function CC.groupStation(group)
	local sg = CC.comp(group, api.type.ComponentType.STATION_GROUP)
	return sg and CC.each(sg.stations)[1]
end

-- La stazione vede l'industria? (confronto sia con l'entita' industria sia con la sua costruzione) DA VERIFICARE
-- il formato degli elementi restituiti: provo sia numeri sia strutture con .entity.
function CC.stationCatches(station, ind)
	local ic = CC.comp(ind, api.type.ComponentType.INDUSTRY)
	local con = ic and ic.construction
	for _, c in ipairs(CC.stationCatchables(station)) do
		local e = c
		if type(c) ~= "number" then pcall(function() e = c.entity end) end
		if e == ind or (con and e == con) then return true end
	end
	return false
end

-- Edifici di citta' entro r metri (stima veloce del bacino passeggeri di un punto).
function CC.townBuildingsNear(x, y, r)
	local n = 0
	pcall(function()
		n = #CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(x, y), r, api.type.ComponentType.TOWN_BUILDING))
	end)
	return n
end

-- Fermata stradale del giocatore entro r metri da (x, y), se c'e' (per riusarla).
function CC.playerStopNear(x, y, r, needRoad)
	local best, bd
	for g in pairs(CC.playerGroups()) do
		local p = CC.posOf(g)
		if p then
			local d = math.sqrt((p.x - x) ^ 2 + (p.y - y) ^ 2)
			if d < r and (not bd or d < bd) then
				local okRoad = true
				if needRoad then
					okRoad = false
					pcall(function()
						local car = api.engine.system.stationGroupSystem.getCarriers(g, -1, -1)
						for _, c in ipairs(CC.each(car[1])) do if c == api.type.enum.Carrier.ROAD then okRoad = true end end
					end)
				end
				if okRoad then best, bd = g, d end
			end
		end
	end
	return best, bd
end
-- ===================================================================== fine b1

-- ===================================================================== BOZZA (NON TESTATO) - b8 collaudo e mappa
-- Collaudo: dopo ogni costruzione (b9 lo chiama da solo) e su richiesta (check_line, check_network) controlla che
-- quello che e' stato costruito funzioni: percorso tra le fermate, veicoli presenti e in movimento, deposito che
-- raggiunge la linea, fermate con citta'/industrie nel bacino. Il middleware lo ripete dopo 1-2 mesi di gioco
-- (passeggeri/merci trasportati). Lettura della mappa per Claude (read_map).
-- DA VERIFICARE in gioco (sonda s9): stato dei veicoli, posizione dei veicoli, statistiche delle linee.

-- Campioni per capire se un veicolo si muove: posizione all'ultimo controllo (si perde se lo script viene ricreato:
-- in quel caso il movimento risulta "non ancora verificabile").
CC._samples = CC._samples or {}


-- Qualita' TF3: campi dalle definizioni api/tealdef, NON verificati su userdata C++.
-- Accessi espliciti: niente pairs/clone/dump o messaggi raw delle eccezioni.
local function qualityField(value, name)
    local ok, field = pcall(function() return value[name] end)
    return ok, field
end

local function qualityFinite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function qualityDatum(value)
    local out = { available = false, errors = {} }
    if type(value) ~= "table" and type(value) ~= "userdata" then
        out.errors[1] = "dato assente o non leggibile"
        return out
    end
    for _, name in ipairs({ "countBad", "countTotal", "averageQuality", "isVeryBad" }) do
        local ok, field = qualityField(value, name)
        if not ok then
            out.errors[#out.errors + 1] = name .. ": accesso non riuscito"
        elseif name == "averageQuality" and field == nil then
            -- Campo opzionale: assente non significa zero.
        else
            local valid
            if name == "isVeryBad" then
                valid = type(field) == "boolean"
            elseif name == "averageQuality" then
                valid = qualityFinite(field)
            else
                valid = qualityFinite(field) and field >= 0 and math.floor(field) == field
            end
            if valid then out[name] = field
            else out.errors[#out.errors + 1] = name .. ": valore assente o tipo non valido" end
        end
    end
    out.available = out.countBad ~= nil and out.countTotal ~= nil and out.isVeryBad ~= nil
    if out.countBad ~= nil and out.countTotal ~= nil then
        if out.countBad > out.countTotal then
            out.available = false
            out.errors[#out.errors + 1] = "countBad maggiore di countTotal"
        elseif out.countTotal > 0 then
            out.bad_fraction = out.countBad / out.countTotal
        end
    end
    return out
end

function CC.normalizeCargoQuality(summary)
    local out = { available = false, errors = {} }
    for _, name in ipairs({ "passengers", "cargo" }) do
        local ok, datum = qualityField(summary, name)
        if not ok then
            out.errors[#out.errors + 1] = name .. ": accesso non riuscito"
            datum = nil
        end
        out[name] = qualityDatum(datum)
        out.available = out.available or out[name].available
    end
    return out
end

function CC.lineCargoQuality(lineId)
    local ok, summary = pcall(function()
        return api.engine.util.cargo.getSummarizedCargoQualityDataForLine(lineId)
    end)
    if not ok then
        local out = CC.normalizeCargoQuality(nil)
        out.errors = { "API qualita' linea non disponibile" }
        return out
    end
    return CC.normalizeCargoQuality(summary)
end

-- Indicatori dalle definizioni TF3: solo booleani, NON moltiplicatori o decisioni automatiche.
-- Userdata C++ non provato: stessi accessi espliciti protetti della qualita'.
function CC.normalizeIndustryProductivity(value)
    local out = { available = false, errors = {} }
    if type(value) ~= "table" and type(value) ~= "userdata" then
        out.errors[1] = "dato produttivita' assente o non leggibile"
        return out
    end
    for _, name in ipairs({ "producing", "boostFromRule", "boostFromPersonCapacity" }) do
        local ok, field = qualityField(value, name)
        if not ok then
            out.errors[#out.errors + 1] = name .. ": accesso non riuscito"
        elseif type(field) == "boolean" then
            out[name] = field
        else
            out.errors[#out.errors + 1] = name .. ": valore assente o tipo non valido"
        end
    end
    out.available = out.producing ~= nil and out.boostFromRule ~= nil
        and out.boostFromPersonCapacity ~= nil
    return out
end

function CC.industryProductivity(industryId)
    local ok, value = pcall(function()
        return api.engine.util.industry.getIndustryProductivityInfo(industryId)
    end)
    if not ok then
        local out = CC.normalizeIndustryProductivity(nil)
        out.errors = { "API produttivita' industria non disponibile" }
        return out
    end
    return CC.normalizeIndustryProductivity(value)
end

-- Stato del veicolo come testo (IN_DEPOT, EN_ROUTE, AT_TERMINAL, GOING_TO_DEPOT ...). DA VERIFICARE i nomi.
function CC.vehicleState(v)
	local tv = CC.comp(v, api.type.ComponentType.TRANSPORT_VEHICLE)
	if not tv then return "?" end
	local s = tv.state
	local name = tostring(s)
	-- VERIFICATO (sonde s9 e p22): l'enum ha i nomi dentro __index (IN_DEPOT 0, EN_ROUTE 1, AT_TERMINAL 2, GOING_TO_DEPOT 3)
	local names = { [0] = "IN_DEPOT", [1] = "EN_ROUTE", [2] = "AT_TERMINAL", [3] = "GOING_TO_DEPOT" }
	pcall(function()
		local E = api.type.enum.TransportVehicleState
		local function scan(t) for k, val in pairs(t) do if type(val) == "table" then scan(val) elseif val == s then names[s] = k end end end
		scan(E)
	end)
	if type(s) == "number" and names[s] then name = names[s] end
	return name
end

-- Getter ufficiale TF3, verificato 13.10 su nave in viaggio; ripieghi per API assente.
function CC.vehiclePos(v)
	local p
	pcall(function()
		local position = api.engine.util.vehicle.getPosition(v)
		if qualityFinite(position.x) and qualityFinite(position.y) then
			p = { x = position.x, y = position.y }
		end
	end)
	if p then return p end
	pcall(function() p = CC.posOf(v) end)
	if p then return p end
	pcall(function()
		local mp = CC.comp(v, api.type.ComponentType.MOVE_PATH)
		local d = mp.dyn
		p = { x = d.pathPos.x, y = d.pathPos.y }
	end)
	return p
end

-- Campioni persistenti (13.10): CC._samples da solo si perdeva tra due check_line (PROVATO IN TF3, causa non
-- certificata). Il lato simulazione (simJob) li ricarica dallo stato della mod (state:get, finisce nel salvataggio
-- della partita) prima di ogni lavoro e li riscrive dopo: cosi' non dipendono dallo script rimasto in memoria e non
-- passano da una partita all'altra. Chiavi testo, solo numeri finiti, al massimo CC.SAMPLES_MAX veicoli recenti.
CC.SAMPLES_MAX = 200

local function sampleValid(s)
	return type(s) == "table" and qualityFinite(s.x) and qualityFinite(s.y) and qualityFinite(s.t)
end

function CC.samplesLoad(saved)
	local out = {}
	if type(saved) == "table" then
		for k, s in pairs(saved) do
			local id = tonumber(k)
			if id and sampleValid(s) then out[id] = { x = s.x, y = s.y, t = s.t } end
		end
	end
	CC._samples = out
	return out
end

function CC.samplesDump()
	local list = {}
	for id, s in pairs(CC._samples or {}) do
		if (type(id) == "number" or tonumber(id)) and sampleValid(s) then list[#list + 1] = { id = id, s = s } end
	end
	table.sort(list, function(a, b)
		if a.s.t ~= b.s.t then return a.s.t > b.s.t end
		return tostring(a.id) < tostring(b.id)
	end)
	local out = {}
	for i = 1, math.min(#list, CC.SAMPLES_MAX) do
		local s = list[i].s
		out[tostring(list[i].id)] = { x = s.x, y = s.y, t = s.t }
	end
	return out
end

-- Statistiche di una linea (passeggeri/merci trasportati, frequenza). I nomi dei campi non sono ancora noti:
-- provo quelli del gioco precedente. DA VERIFICARE con la sonda s9; quelli che non esistono restano nil.
function CC.lineStats(L)
	local st = {}
	local lc = CC.comp(L, api.type.ComponentType.LINE)
	for _, f in ipairs({ "itemsTransported", "transported", "frequency", "rate" }) do
		pcall(function() local v = lc[f]; if v ~= nil then st[f] = type(v) == "number" and v or tostring(v) end end)
	end
	pcall(function() st.frequency = st.frequency or api.engine.util.line.getFrequency(L) end)
	pcall(function() st.rate = st.rate or api.engine.util.line.getRate(L) end)
	pcall(function()
		local ent = game.interface.getEntity(L)
		if ent then
			st.itemsTransported = st.itemsTransported or ent.itemsTransported
			st.frequency = st.frequency or ent.frequency
		end
	end)
	return st
end

-- C'e' un'altra stazione del giocatore (gruppo diverso) entro r metri dal gruppo g? (scambio a piedi)
function CC.otherStationNear(g, r)
	local p = CC.posOf(g)
	if not p then return false end
	local found = false
	pcall(function()
		for _, st in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), r, api.type.ComponentType.STATION))) do
			local og = api.engine.system.stationGroupSystem.getStationGroup(st)
			if og and og ~= g and og >= 0 then found = true; break end
		end
	end)
	return found
end

-- Controllo di una linea. Ritorna { ok, problems = { testo }, suggestions = { testo }, ... }.
function CC.checkLine(L)
	local CT = api.type.ComponentType
	local r = { line_id = L, problems = {}, suggestions = {} }
	local lc = CC.comp(L, CT.LINE)
	if not lc then r.ok = false; r.problems[1] = "la linea non esiste"; return r end
	r.name = CC.nameOf(L)
	local groups = CC.lineGroups(L) or {}
	r.stops = #groups
	if #groups < 2 then r.problems[#r.problems + 1] = "la linea ha meno di 2 fermate" end
	local vs = CC.lineVehicles(L)
	r.vehicles = #vs
	if #vs == 0 then
		r.problems[#r.problems + 1] = "nessun veicolo sulla linea"
		r.suggestions[#r.suggestions + 1] = "aggiungere veicoli (add_vehicles o create_line_from_stations)"
	end
	-- modi della linea (o del primo veicolo)
	local modes = CC.lineModes(L)
	if #modes == 0 and vs[1] then
		pcall(function()
			for _, tm in ipairs(CC.each(api.res.modelRep.get(CC.vehicleModels(vs[1])[1]).metadata.transportVehicle.engineTransportModes)) do modes[#modes + 1] = tm end
		end)
	end
	-- percorso tra fermate consecutive (anche dall'ultima alla prima: la linea gira), con la stazione e il terminale
	-- indicati dalla fermata (VERIFICATO s14 sul salvataggio di terzi: nessun falso "nessun percorso")
	local stops = CC.lineStops(L)
	-- TF3: il grafo a nodi puo' collegare i porti anche quando il percorso navale
	-- effettivo non esiste. Per le navi conservare anche il controllo nativo della linea.
	local nativeNoPath = {}
	local TM = api.type.enum.TransportMode
	local waterLine = false
	for _, mode in ipairs(modes) do
		if mode == (TM.SHIP or 12) or mode == (TM.SMALL_SHIP or 13) then waterLine = true end
	end
	if waterLine then
		pcall(function()
			for i, states in ipairs(CC.each(api.engine.util.line.getDetailedLineProblems(L))) do
				for _, state in ipairs(CC.each(states)) do
					if state.noPath == true then nativeNoPath[i] = true end
				end
			end
		end)
	end
	if #modes > 0 then
		for i = 1, #stops do
			local j = i % #stops + 1
			if stops[i].stationGroup ~= stops[j].stationGroup
				and (nativeNoPath[i] or (not CC.hasPath(CC.lineStopNode(stops[i]), CC.lineStopNode(stops[j]), modes)
				and not CC.groupPath(stops[i].stationGroup, stops[j].stationGroup, modes))) then
				r.problems[#r.problems + 1] = "nessun percorso dalla fermata " .. i .. " (" .. (CC.nameOf(groups[i]) or "?") .. ") alla " .. j
				r.suggestions[#r.suggestions + 1] = "collegare le due fermate (strada/binario mancante o senso unico)"
			end
		end
	end
	-- deposito
	if not CC.depotForLine(L) then
		r.problems[#r.problems + 1] = "nessun deposito raggiunge la linea"
		r.suggestions[#r.suggestions + 1] = "costruire un deposito collegato (build_depot)"
	end
	-- bacino delle fermate. VERIFICATO sul salvataggio di terzi (94 linee che funzionano): molte fermate non hanno
	-- edifici nel bacino ma servono da nodo di scambio (fermata bus davanti alla stazione, metropolitana, porti,
	-- monumenti). Una fermata senza bacino e' solo una nota se: il gruppo e' servito da altre linee, oppure c'e' un'altra
	-- stazione del giocatore entro 250 m. La linea ha un problema solo se meno di 2 fermate servono a qualcosa.
	local counts = CC._lineCounts or CC.groupLineCounts()
	r.notes = {}
	local useful = 0
	for i, g in ipairs(groups) do
		if CC.groupCatchables(g) > 0 then
			useful = useful + 1
		elseif (counts[g] or 0) > 1 or CC.otherStationNear(g, 250) then
			useful = useful + 1
			r.notes[#r.notes + 1] = "fermata " .. i .. " (" .. (CC.nameOf(g) or "?") .. "): nodo di scambio senza edifici nel bacino"
		else
			r.notes[#r.notes + 1] = "fermata " .. i .. " (" .. (CC.nameOf(g) or "?") .. "): nessun edificio o industria nel bacino"
		end
	end
	if #groups >= 2 and useful < 2 then
		r.problems[#r.problems + 1] = "meno di 2 fermate hanno edifici, industrie o coincidenze nel bacino: la linea trasporta poco o nulla"
		r.suggestions[#r.suggestions + 1] = "spostare le fermate verso il centro o collegarle con una navetta"
	end
	-- veicoli: stato e movimento rispetto all'ultimo controllo
	local states, still, moved, unknown = {}, 0, 0, 0
	-- perche' il movimento non e' verificabile: serve a distinguere in TF3 campioni persi e tempo fermo
	local reasons = { no_position = 0, no_previous = 0, time_not_advanced = 0 }
	local now = 0
	local timeOk = pcall(function() now = CC.comp(api.engine.util.getWorld(), CT.GAME_TIME).gameTime end)
	if not qualityFinite(now) then now = 0; timeOk = false end
	CC._samples = CC._samples or {}
	for _, v in ipairs(vs) do
		local s = CC.vehicleState(v)
		states[s] = (states[s] or 0) + 1
		local p = CC.vehiclePos(v)
		local prev = CC._samples[v]
		if p and prev and now > prev.t then
			if (p.x - prev.x) ^ 2 + (p.y - prev.y) ^ 2 < 4 and s ~= "AT_TERMINAL" and s ~= "IN_DEPOT" then still = still + 1 else moved = moved + 1 end
		else
			unknown = unknown + 1
			if not p then reasons.no_position = reasons.no_position + 1
			elseif not prev then reasons.no_previous = reasons.no_previous + 1
			else reasons.time_not_advanced = reasons.time_not_advanced + 1 end
		end
		if p then CC._samples[v] = { x = p.x, y = p.y, t = now } end
	end
	r.vehicle_states = states
	r.vehicles_moving = moved
	r.vehicles_still = still
	r.movement_unknown = unknown
	r.movement_unknown_reasons = reasons
	r.sample_time = now
	r.game_time_read = timeOk and now > 0
	if still > 0 then
		r.problems[#r.problems + 1] = still .. " veicoli fermi dall'ultimo controllo"
		r.suggestions[#r.suggestions + 1] = "controllare blocchi (segnali, binario unico con troppi treni, strada interrotta)"
	end
	if (states.IN_DEPOT or 0) == #vs and #vs > 0 then
		r.problems[#r.problems + 1] = "tutti i veicoli sono ancora nel deposito"
	end
	r.stats = CC.lineStats(L)
	r.ok = #r.problems == 0
	return r
end

SIM_ACTIONS.check_line = function(a)
	CC.need(a, { line_id = "id" })
	return CC.checkLine(a.line_id)
end

-- Tutte le linee del giocatore: solo quelle con problemi (al massimo max_lines controllate).
SIM_ACTIONS.check_network = function(a)
	CC.need(a or {}, { max_lines = "int?" })
	local lines = {}
	pcall(function() lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer())) end)
	local bad, okN = {}, 0
	CC._lineCounts = CC.groupLineCounts()
	for i = 1, math.min(#lines, (a and a.max_lines) or 40) do
		local r = CC.checkLine(lines[i])
		if r.ok then okN = okN + 1 else bad[#bad + 1] = { line_id = r.line_id, name = r.name, problems = r.problems, suggestions = r.suggestions } end
	end
	CC._lineCounts = nil
	return { ok = true, lines_checked = math.min(#lines, (a and a.max_lines) or 40), lines_ok = okN, lines_with_problems = bad }
end

-- ---------------------------------------------------------------- lettura della mappa
-- Riassunto per pianificare: estensione, griglia di quote e acqua, citta' (con edifici = grandezza), industrie con
-- merci, linee esistenti. grid: punti per lato (4-16, default 10).
SIM_ACTIONS.read_map = function(a)
	CC.need(a or {}, { grid = "int?" })
	local CT = api.type.ComponentType
	local N = math.max(4, math.min(16, (a and a.grid) or 10))
	local minX, minY, maxX, maxY
	local function ext(p)
		if not p then return end
		minX = math.min(minX or p.x, p.x); maxX = math.max(maxX or p.x, p.x)
		minY = math.min(minY or p.y, p.y); maxY = math.max(maxY or p.y, p.y)
	end
	local towns, inds = {}, {}
	for _, t in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.TOWN))) do
		local p = CC.posOf(t)
		ext(p)
		if p then towns[#towns + 1] = { id = t, name = CC.nameOf(t), x = math.floor(p.x), y = math.floor(p.y), z = math.floor(p.z or 0),
			buildings = CC.townBuildingsNear(p.x, p.y, 700) } end
	end
	table.sort(towns, function(u, v) return u.buildings > v.buildings end)
	for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.INDUSTRY))) do
		local p = CC.posOf(e)
		ext(p)
		local ins, outs = CC.industryCargo(e)
		local inN, outN = {}, {}
		for _, c in ipairs(ins or {}) do inN[#inN + 1] = CC.cargoName(c) end
		for _, c in ipairs(outs or {}) do outN[#outN + 1] = CC.cargoName(c) end
		if p then inds[#inds + 1] = { id = e, name = CC.nameOf(e), x = math.floor(p.x), y = math.floor(p.y),
			inputs = inN, outputs = outN, productivity = CC.industryProductivity(e) } end
	end
	if not minX then return { ok = false, error = "mappa vuota?" } end
	local pad = 1500
	minX, minY, maxX, maxY = minX - pad, minY - pad, maxX + pad, maxY + pad
	local heights, water = {}, {}
	for j = 0, N - 1 do
		local y = maxY - (maxY - minY) * j / (N - 1)
		local hrow, wrow = {}, {}
		for i = 0, N - 1 do
			local x = minX + (maxX - minX) * i / (N - 1)
			hrow[#hrow + 1] = math.floor((CC.heightAt(x, y) or 0) + 0.5)
			wrow[#wrow + 1] = CC.onWater(x, y) and "~" or "."
		end
		heights[#heights + 1] = hrow
		water[#water + 1] = table.concat(wrow)
	end
	local lines = {}
	pcall(function()
		for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
			lines[#lines + 1] = { id = L, name = CC.nameOf(L), stops = #(CC.lineGroups(L) or {}), vehicles = #CC.lineVehicles(L) }
		end
	end)
	return { ok = true, year = CC.year(), bounds = { minX = math.floor(minX), minY = math.floor(minY), maxX = math.floor(maxX), maxY = math.floor(maxY) },
		grid = N, heights = heights, water = water, water_legend = "righe da nord (y max) a sud, colonne da ovest a est; ~ acqua",
		towns = towns, industries = inds, lines = lines }
end
-- ===================================================================== fine b8



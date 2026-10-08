-- SONDA 23 (sola lettura): dati per l'analisi della flotta ON-DEMAND (numero di veicoli alla creazione e
-- "adegua i veicoli della linea X"). Cerca: tempo di un giro, intervallo, eta'/vita dei veicoli, capienza,
-- passeggeri/merci in attesa alle fermate. Serve almeno una linea con veicoli in movimento da qualche minuto.
-- Uso: CC.PROBE_LINE = <id linea> (facoltativo; altrimenti le prime 2 linee del giocatore).
local CT = api.type.ComponentType
local out = { api = {}, lines = {} }
local function keys(t, max)
	local r = {}
	pcall(function() for k, v in pairs(t) do r[#r + 1] = tostring(k) .. ":" .. type(v); if #r >= (max or 80) then break end end end)
	pcall(function()
		local mt = getmetatable(t)
		if mt and type(mt.__index) == "table" then for k in pairs(mt.__index) do r[#r + 1] = "mt." .. tostring(k) end end
	end)
	table.sort(r)
	return r
end
local function str(x, n) local ok, s = pcall(tostring, x); s = ok and s or "?"; return #s > (n or 600) and s:sub(1, n or 600) .. "..." or s end
local function try(name, f, ...)
	local ok, r = pcall(f, ...)
	if ok then return str(r, 500) end
	return "ERR " .. str(r, 150)
end

-- funzioni disponibili (per sapere cosa provare)
out.api.util_line = keys(api.engine.util.line)
out.api.systems = keys(api.engine.system, 120)
out.api.vehicle_util = keys(api.engine.util.vehicle or {})

local lines = {}
if CC.PROBE_LINE then lines = { CC.PROBE_LINE } else
	pcall(function()
		for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
			if #lines < 2 then lines[#lines + 1] = L end
		end
	end)
end

for _, L in ipairs(lines) do
	local r = { id = L, name = CC.nameOf(L), fn = {} }
	local lc = CC.comp(L, CT.LINE)
	r.line_fields = keys(lc)
	r.line_raw = str(lc, 800)
	-- funzioni di util.line con l'id della linea
	for _, n in ipairs({ "getMaxFrequency", "getFrequency", "getLineCapacityUsages", "calcLineStationThroughput",
		"getLineProblems", "getDetailedLineProblems", "getLineIssues", "getRoundTripTime", "getLineDuration",
		"getLineStatistics", "getLineRate", "getLineInterval" }) do
		local f = api.engine.util.line[n]
		r.fn[n] = f and try(n, f, L) or "assente"
	end
	-- sistemi che potrebbero dare tempi/statistiche
	pcall(function()
		local ls = api.engine.system.lineSystem
		for _, n in ipairs({ "getLineStops", "getLineFrequency", "getRoundTripTime", "getLineStatistics", "getLineRate" }) do
			if ls[n] then r.fn["lineSystem." .. n] = try(n, ls[n], L) end
		end
	end)
	-- veicoli: stato, eta', configurazione (prima e' sufficiente)
	local vs = CC.lineVehicles(L)
	r.vehicles = #vs
	local v = vs[1]
	if v then
		local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
		r.veh_fields = keys(tv)
		r.veh_raw = str(tv, 1200)
		pcall(function()
			local cfg = tv.transportVehicleConfig
			r.cfg_fields = keys(cfg)
			local first = CC.each(cfg.vehicles)[1]
			r.cfg_vehicle_fields = keys(first)
			r.cfg_vehicle_raw = str(first, 600)
			local m = api.res.modelRep.get(first.part.modelId)
			r.model_metadata = keys(m.metadata, 60)
			pcall(function() r.model_maintenance = str(m.metadata.maintenance, 300) end)
			pcall(function() r.model_transport = str(m.metadata.transportVehicle, 400) end)
		end)
		for _, ct in ipairs({ "VEHICLE", "MOVE_PATH", "SIM_ENTITY", "MAINTENANCE", "VEHICLE_CONDITION" }) do
			if CT[ct] then
				local c = CC.comp(v, CT[ct])
				if c then r["comp_" .. ct] = keys(c, 40) end
			end
		end
		pcall(function() r.fn.vehicleSystem = keys(api.engine.system.transportVehicleSystem, 60) end)
	end
	-- attese alle fermate
	r.stops = {}
	for i, s in ipairs(CC.lineStops(L)) do
		if i > 3 then break end
		local st = { group = s.stationGroup }
		local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
		st.group_fields = keys(sg)
		pcall(function()
			local stn = CC.each(sg.stations)[s.station + 1] or CC.each(sg.stations)[1]
			local sc = CC.comp(stn, CT.STATION)
			st.station_fields = keys(sc)
			local term = CC.each(sc.terminals)[s.terminal + 1]
			st.terminal_fields = keys(term)
			st.terminal_raw = str(term, 400)
		end)
		pcall(function()
			for _, n in ipairs({ "simEntityAtTerminalSystem", "simPersonSystem", "simCargoSystem", "simEntityAtStationSystem" }) do
				local sys = api.engine.system[n]
				if sys then st["sys_" .. n] = keys(sys, 30) end
			end
		end)
		r.stops[#r.stops + 1] = st
	end
	out.lines[#out.lines + 1] = r
end
out.note = #lines == 0 and "nessuna linea del giocatore: costruirne una e rieseguire" or nil
return out

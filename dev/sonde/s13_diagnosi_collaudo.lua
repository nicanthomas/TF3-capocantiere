-- SONDA 13 (sola lettura): perche' il collaudo (b8) segnala problemi su linee che funzionano (salvataggio di terzi).
-- Confronta: nodo della fermata dalla PRIMA stazione del gruppo (come fa oggi CC.stopNodeId) e dalla stazione/
-- terminale indicati dalla fermata della linea (stop.station, stop.terminal); bacino per ogni stazione del gruppo;
-- funzioni ufficiali api.engine.util.line.* (problemi della linea); durata del mese; binari via octree.
local CT = api.type.ComponentType
local out = { lines = {}, util = {}, edges = {} }
local function tostr(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 3 then return tostring(v) end
	local r, n = {}, 0
	local ok = pcall(function() for k, x in pairs(v) do n = n + 1; if n <= 40 then r[tostring(k)] = tostr(x, depth + 1) end end end)
	if (not ok or n == 0) then
		local okE, list = pcall(CC.each, v)
		if okE and #list > 0 then
			r = {}
			for i = 1, math.min(40, #list) do r[i] = tostr(list[i], depth + 1) end
			return r
		end
		return tostring(v)
	end
	return r
end
local function nodeOf(group, si, ti)
	local sg = CC.comp(group, CT.STATION_GROUP)
	local st = sg and CC.each(sg.stations)[si]
	local s = st and CC.comp(st, CT.STATION)
	local t = s and CC.each(s.terminals)[ti]
	return t and t.vehicleNodeId, st
end
local ids = { 336242, 333826, 300989, 350287, 241012, 213814, 235353 }
for _, L in ipairs(ids) do
	local lc = CC.comp(L, CT.LINE)
	if lc then
		local modes = CC.lineModes(L)
		local r = { id = L, name = CC.nameOf(L), modes = modes, stops = {}, util = {} }
		local stops = CC.each(lc.stops)
		for i, s in ipairs(stops) do
			local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
			local info = { group = s.stationGroup, station = s.station, terminal = s.terminal, nStations = sg and #CC.each(sg.stations) }
			pcall(function() info.alternativeTerminals = tostr(s.alternativeTerminals) end)
			info.nodeFirst = CC.stopNodeId(s.stationGroup)
			local nodeStop, st = nodeOf(s.stationGroup, (s.station or 0) + 1, (s.terminal or 0) + 1)
			info.nodeStop = nodeStop
			info.catch = {}
			pcall(function()
				for k, x in ipairs(CC.each(sg.stations)) do
					local a, b = -1, -1
					pcall(function() a = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(x, true)) end)
					pcall(function() b = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(x, false)) end)
					local sc = CC.comp(x, CT.STATION)
					info.catch[k] = { station = x, t = a, f = b, cargo = sc and sc.cargo, terminals = sc and #CC.each(sc.terminals) }
				end
			end)
			r.stops[i] = info
		end
		for i = 1, #stops do
			local j = i % #stops + 1
			local a, b = r.stops[i], r.stops[j]
			r.stops[i].pathFirst = CC.hasPath(a.nodeFirst, b.nodeFirst, modes)
			r.stops[i].pathStop = CC.hasPath(a.nodeStop, b.nodeStop, modes)
		end
		for _, fn in ipairs({ "getLineProblems", "getDetailedLineProblems", "getLineIssues", "getLineStationProblems",
			"getNoRoadConnectionProblems", "getMaxFrequency", "getLineTransportModesUnion", "getLineCapacityUsages",
			"calcLineStationThroughput", "getFailedPathReason" }) do
			local ok, v = pcall(api.engine.util.line[fn], L)
			r.util[fn] = ok and tostr(v) or ("ERR " .. tostring(v):sub(1, 120))
		end
		pcall(function() r.vehicleInfo = tostr(lc.vehicleInfo) end)
		pcall(function() r.stop1 = tostr(stops[1]) end)
		out.lines[#out.lines + 1] = r
	end
end
for _, fn in ipairs({ "getMonthDuration", "getDefaultMonthDuration", "getYearDuration", "getDefaultDayDuration" }) do
	local ok, v = pcall(api.util[fn])
	out.util[fn] = ok and tostr(v) or ("ERR " .. tostring(v):sub(1, 120))
end
pcall(function() out.util.calendarDate = tostr(api.engine.util.getCalendarDate()) end)
pcall(function() out.util.gameTime = CC.comp(api.engine.util.getWorld(), CT.GAME_TIME).gameTime end)
-- binari e strade via octree (getEntitiesWithComponent(BASE_EDGE) non e' permesso)
local seen, tracks, streets, objs, tmpl = {}, 0, 0, 0, {}
for gx = -8000, 8000, 2000 do
	for gy = -8000, 8000, 2000 do
		pcall(function()
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1450, CT.BASE_EDGE))) do
				if not seen[e] then
					seen[e] = true
					local be = CC.comp(e, CT.BASE_EDGE)
					local tr = CC.comp(e, CT.BASE_EDGE_TRACK)
					if tr then
						tracks = tracks + 1
						local n = 0
						pcall(function() n = #CC.each(be.objects) end)
						objs = objs + n
						local k = tostring(tr.trackType) .. "/cat" .. tostring(tr.catenary)
						tmpl[k] = (tmpl[k] or 0) + 1
						if n > 0 and not out.edges.sampleObj then
							out.edges.sampleObj = { edge = e, objects = tostr(be.objects), track = tostr(tr) }
						end
					elseif CC.comp(e, CT.BASE_EDGE_STREET) then
						streets = streets + 1
					end
				end
			end
		end)
	end
end
out.edges.tracks, out.edges.streets, out.edges.trackObjects, out.edges.trackTypes = tracks, streets, objs, tmpl
return out

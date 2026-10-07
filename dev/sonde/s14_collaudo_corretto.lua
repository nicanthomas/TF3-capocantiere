-- SONDA 14 (sola lettura): verifica delle correzioni al collaudo sul salvataggio di terzi.
-- 1) modi di trasporto: CC.lineModes (oggi indice-1) contro getLineTransportModesUnion e indice senza -1
-- 2) collaudo di tutte le linee con i modi corretti e il nodo della fermata indicato dalla linea (stop.station/terminal)
-- 3) problemi ufficiali della linea (getDetailedLineProblems) in chiaro
-- 4) com'e' fatto un binario (BASE_EDGE vicino a una stazione ferroviaria): campi e componenti presenti
local CT = api.type.ComponentType
local out = { modes = {}, lines = {}, edge = {}, depots = {} }
local function plain(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 4 then return tostring(v) end
	local r, n = {}, 0
	pcall(function() for k, x in pairs(v) do n = n + 1; if n <= 30 then r[tostring(k)] = plain(x, depth + 1) end end end)
	if n == 0 then
		local okE, list = pcall(CC.each, v)
		if okE and #list > 0 then
			for i = 1, math.min(30, #list) do r[i] = plain(list[i], depth + 1) end
			return r
		end
		for _, f in ipairs({ "type", "problem", "stop", "stopIndex", "entity", "name", "value", "reason", "x", "y" }) do
			pcall(function() local x = v[f]; if x ~= nil then r[f] = plain(x, depth + 1) end end)
		end
		if next(r) == nil then return tostring(v) end
	end
	return r
end
local function modesUnion(L)
	local m = {}
	pcall(function()
		for k, on in pairs(api.engine.util.line.getLineTransportModesUnion(L)) do if on then m[#m + 1] = tonumber(k) or k end end
	end)
	table.sort(m, function(a, b) return tostring(a) < tostring(b) end)
	return m
end
local function modesNoShift(L)
	local m = {}
	pcall(function()
		local tm = CC.comp(L, CT.LINE).vehicleInfo.transportModes
		for i = 0, 32 do
			local on = false
			pcall(function() on = tm[i] end)
			if on then m[#m + 1] = i end
		end
	end)
	return m
end
local function stopNode(s)
	local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
	local st = sg and CC.each(sg.stations)[(s.station or 0) + 1]
	local sc = st and CC.comp(st, CT.STATION)
	local t = sc and CC.each(sc.terminals)[(s.terminal or 0) + 1]
	return t and t.vehicleNodeId, st
end
local lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))
local okLines, badLines = 0, 0
for i, L in ipairs(lines) do
	local lc = CC.comp(L, CT.LINE)
	local stops = CC.each(lc.stops)
	local mU, mN, mOld = modesUnion(L), modesNoShift(L), CC.lineModes(L)
	if i <= 12 then out.modes[#out.modes + 1] = { id = L, name = CC.nameOf(L), union = mU, noShift = mN, old = mOld } end
	local r = { id = L, name = CC.nameOf(L), problems = {} }
	local modes = #mU > 0 and mU or mN
	for k = 1, #stops do
		local j = k % #stops + 1
		local a, sa = stopNode(stops[k])
		local b = stopNode(stops[j])
		if stops[k].stationGroup ~= stops[j].stationGroup and not CC.hasPath(a, b, modes) then
			r.problems[#r.problems + 1] = "path " .. k .. "->" .. j
		end
		local nC = -1
		pcall(function() nC = #CC.each(api.engine.system.catchmentAreaSystem.getStationCatchables(sa, true)) end)
		if nC == 0 then r.problems[#r.problems + 1] = "bacino vuoto fermata " .. k end
	end
	pcall(function() r.official = plain(api.engine.util.line.getDetailedLineProblems(L)) end)
	pcall(function() r.issues = plain(api.engine.util.line.getLineIssues(L)) end)
	if #r.problems == 0 then okLines = okLines + 1 else badLines = badLines + 1 end
	if #r.problems > 0 or i <= 6 then
		if #out.lines < 25 then out.lines[#out.lines + 1] = r end
	end
end
out.okLines, out.badLines = okLines, badLines
-- deposito/officina che raggiunge la linea: per le prime 8 linee, con i modi corretti
for i = 1, math.min(8, #lines) do
	local L = lines[i]
	local lc = CC.comp(L, CT.LINE)
	local s1 = CC.each(lc.stops)[1]
	local target = stopNode(s1)
	local modes = modesUnion(L)
	local p = CC.posOf(s1.stationGroup)
	local found
	local list = CC.playerDepots()
	table.sort(list, function(a, b)
		local da = (a.x and p) and ((a.x - p.x) ^ 2 + (a.y - p.y) ^ 2) or 1e18
		local db = (b.x and p) and ((b.x - p.x) ^ 2 + (b.y - p.y) ^ 2) or 1e18
		return da < db
	end)
	for k = 1, math.min(10, #list) do
		local dOut = CC.depotNodes(list[k].depot)
		if CC.hasPath(dOut, target, modes) then found = list[k].file; break end
	end
	out.depots[#out.depots + 1] = { id = L, name = CC.nameOf(L), depot = found or false, candidates = #list }
end
-- binario: segmenti vicino alla prima stazione ferroviaria del giocatore
pcall(function()
	for _, L in ipairs(lines) do
		local mU = modesUnion(L)
		local isTrain = false
		for _, m in ipairs(mU) do if m == 7 or m == 8 then isTrain = true end end
		if isTrain then
			local s1 = CC.each(CC.comp(L, CT.LINE).stops)[1]
			local p = CC.posOf(s1.stationGroup)
			local n = 0
			for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 400, CT.BASE_EDGE))) do
				local be = CC.comp(e, CT.BASE_EDGE)
				local item = { id = e, base = plain(be), comps = {} }
				for name, id in pairs(CT) do
					local okC, c = pcall(api.engine.getComponent, e, id)
					if okC and c then item.comps[#item.comps + 1] = name end
				end
				n = n + 1
				out.edge[#out.edge + 1] = item
				if n >= 4 then break end
			end
			break
		end
	end
end)
return out

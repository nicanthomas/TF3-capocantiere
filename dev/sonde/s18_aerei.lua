-- SONDA 18: perche' l'aereo non si assegna alla linea tra due campi d'aviazione (prova p20). Legge terminali e nodi
-- delle due stazioni, percorsi deposito -> terminali e tra terminali con i modi 9 e 11, poi riprova l'assegnazione.
local CT = api.type.ComponentType
local L, V, D = 13619, 14374, 93164
local out = { stops = {}, paths = {} }
local lc = CC.comp(L, CT.LINE)
out.lineExists = lc ~= nil
out.modes = CC.lineModes(L)
local nodes = {}
for i, s in ipairs(CC.lineStops(L)) do
	local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
	local info = { group = s.stationGroup, station = s.station, terminal = s.terminal, terminals = {} }
	for si, st in ipairs(sg and CC.each(sg.stations) or {}) do
		local sc = CC.comp(st, CT.STATION)
		for ti, t in ipairs(sc and CC.each(sc.terminals) or {}) do
			info.terminals[#info.terminals + 1] = { s = si - 1, t = ti - 1, node = tostring(t.vehicleNodeId) }
			nodes[#nodes + 1] = { stop = i, s = si - 1, t = ti - 1, n = t.vehicleNodeId }
		end
	end
	out.stops[i] = info
end
local dOut, dIn = CC.depotNodes(D)
out.depotOut = tostring(dOut)
for _, m in ipairs({ 9, 11 }) do
	for _, nd in ipairs(nodes) do
		out.paths[#out.paths + 1] = { mode = m, stop = nd.stop, t = nd.t, fromDepot = CC.hasPath(dOut, nd.n, { m }) }
	end
	local a, b = nodes[1], nodes[#nodes]
	if a and b then out.paths[#out.paths + 1] = { mode = m, between = true, ok = CC.hasPath(a.n, b.n, { m }) } end
end
pcall(function() out.problems = tostring(api.engine.util.line.getLineProblems(L)) end)
local tv = CC.comp(V, CT.TRANSPORT_VEHICLE)
out.vehicleState = tv and tostring(tv.state)
for _, k in ipairs({ 0, 1 }) do
	local ok, res = CC.send(api.cmd.makeVehicleSetLineCmd(V, L, k))
	out["assign_" .. k] = ok
	if not ok then pcall(function() out["assignErr_" .. k] = tostring(res.resultStatus or res) end) end
end
return out

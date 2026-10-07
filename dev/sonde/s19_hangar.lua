-- SONDA 19: hangar dei due campi d'aviazione della prova p20: nodi di uscita/entrata e percorsi verso i terminali.
local CT = api.type.ComponentType
local out = {}
local nodes = {}
for i, s in ipairs(CC.lineStops(13619)) do
	local sg = CC.comp(s.stationGroup, CT.STATION_GROUP)
	local sc = CC.comp(CC.each(sg.stations)[1], CT.STATION)
	for ti, t in ipairs(CC.each(sc.terminals)) do nodes[#nodes + 1] = { stop = i, t = ti - 1, n = t.vehicleNodeId } end
	-- costruzione della stazione e suoi depositi
	pcall(function()
		local con = api.engine.system.streetConnectorSystem.getConstructionEntityForStation(CC.each(sg.stations)[1])
		local c = CC.comp(con, CT.CONSTRUCTION)
		for _, d in ipairs(CC.each(c.depots)) do
			local vd = CC.comp(d, CT.VEHICLE_DEPOT)
			local r = { stop = i, depot = d, outs = {}, ins = {} }
			for _, n in ipairs(CC.each(vd.outNodes)) do r.outs[#r.outs + 1] = n end
			for _, n in ipairs(CC.each(vd.inNodes)) do r.ins[#r.ins + 1] = n end
			pcall(function() r.fields = tostring(vd) end)
			out[#out + 1] = r
		end
	end)
end
for _, r in ipairs(out) do
	r.paths = {}
	for k, o in ipairs(r.outs) do
		for _, nd in ipairs(nodes) do
			for _, m in ipairs({ 9, 11 }) do
				if CC.hasPath(o, nd.n, { m }) then r.paths[#r.paths + 1] = "out" .. k .. "->stop" .. nd.stop .. "t" .. nd.t .. " m" .. m end
			end
		end
		r.outs[k] = tostring(o)
	end
	for k, n in ipairs(r.ins) do r.ins[k] = tostring(n) end
end
return out

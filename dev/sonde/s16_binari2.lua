-- SONDA 16 (sola lettura): tipi di segmento (roadTemplate) attorno alle stazioni ferroviarie, campi di un segmento di
-- binario e dei suoi oggetti (segnali), conteggio SIGNAL_LIST. Serve a CC.nearestTrack/b6 (oggi cercano "/track/").
local CT = api.type.ComponentType
local out = { templates = {}, trackSample = nil, objects = {} }
local function field(o, f)
	local ok, v = pcall(function() return o[f] end)
	if not ok then return "ERR" end
	if type(v) == "userdata" then
		local okE, list = pcall(CC.each, v)
		if okE and #list > 0 then
			local r = {}
			for i = 1, math.min(8, #list) do
				local x = list[i]
				if type(x) == "userdata" then
					local rr = {}
					pcall(function() rr[1] = x[1]; rr[2] = x[2] end)
					x = next(rr) and rr or tostring(x)
				end
				r[i] = x
			end
			r.n = #list
			return r
		end
		local okX, xy = pcall(function() return { v.x, v.y, v.z } end)
		if okX and xy[1] then return xy end
		return tostring(v)
	end
	return v
end
local stations = {}
for _, L in ipairs(CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))) do
	for _, m in ipairs(CC.lineModes(L)) do
		if m == 7 or m == 8 then
			for _, s in ipairs(CC.lineStops(L)) do stations[#stations + 1] = s.stationGroup end
			break
		end
	end
	if #stations >= 6 then break end
end
out.trainStations = #stations
local seen = {}
for _, g in ipairs(stations) do
	local p = CC.posOf(g)
	if p then
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 600, CT.BASE_EDGE))) do
			if not seen[e] then
				seen[e] = true
				local be = CC.comp(e, CT.BASE_EDGE)
				local t = be and tostring(be.roadTemplate) or "?"
				local st = CC.comp(e, CT.BASE_EDGE_STREET)
				local key = t .. (st and "" or " [no STREET comp]")
				out.templates[key] = (out.templates[key] or 0) + 1
				if not t:find("/street/", 1, true) and not out.trackSample then
					local item = { id = e, template = t, inConstruction = CC.inConstruction and CC.inConstruction(e) or nil }
					for _, f in ipairs({ "type", "typeIndex", "objects", "node0", "node1", "position0", "position1" }) do item[f] = field(be, f) end
					for _, n in ipairs({ "BASE_EDGE_STREET", "TRANSPORT_NETWORK", "EDGE_OBJECT", "MODEL_INSTANCE_LIST", "SIGNAL_LIST" }) do
						local okC, c = pcall(api.engine.getComponent, e, CT[n])
						item["has_" .. n] = okC and c ~= nil
					end
					out.trackSample = item
				end
				if not t:find("/street/", 1, true) and #out.objects < 6 then
					local objs = field(be, "objects")
					if type(objs) == "table" and (objs.n or 0) > 0 then
						for i = 1, (objs.n or 0) do
							local o = objs[i]
							local ent = type(o) == "table" and o[1] or o
							local r = { edge = e, raw = o, comps = {} }
							if type(ent) == "number" then
								for _, n in ipairs({ "EDGE_OBJECT", "SIGNAL_LIST", "MODEL_INSTANCE_LIST", "NAME", "CONSTRUCTION" }) do
									local okC, c = pcall(api.engine.getComponent, ent, CT[n])
									if okC and c then
										r.comps[n] = {}
										for _, f in ipairs({ "edgeEntity", "param", "left", "oneWay", "model", "modelId", "signals", "type", "name", "fileName" }) do
											local v = field(c, f)
											if v ~= nil and v ~= "ERR" then r.comps[n][f] = v end
										end
									end
								end
							end
							out.objects[#out.objects + 1] = r
						end
					end
				end
			end
		end
	end
end
pcall(function() out.signalLists = #CC.each(api.engine.getEntitiesWithComponent(CT.SIGNAL_LIST)) end)
pcall(function() out.edgeObjects = #CC.each(api.engine.getEntitiesWithComponent(CT.EDGE_OBJECT)) end)
return out

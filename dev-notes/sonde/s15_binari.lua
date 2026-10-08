-- SONDA 15 (sola lettura): come si riconosce un binario in TF3 (BASE_EDGE_TRACK risulta assente) e dove stanno i
-- segnali. Legge i segmenti vicino a una stazione ferroviaria del giocatore, campo per campo.
local CT = api.type.ComponentType
local out = { ctNames = {}, edges = {} }
for _, n in ipairs({ "BASE_EDGE", "BASE_EDGE_TRACK", "BASE_EDGE_STREET", "BASE_NODE", "TRACK", "STREET", "SIGNAL",
	"SIGNAL_LIST", "EDGE_OBJECT", "MODEL_INSTANCE_LIST", "TRANSPORT_NETWORK", "NETWORK_EDGE" }) do
	out.ctNames[n] = CT[n] ~= nil
end
local function field(o, f)
	local ok, v = pcall(function() return o[f] end)
	if not ok then return "ERR" end
	if type(v) == "userdata" then
		local okE, list = pcall(CC.each, v)
		if okE and #list > 0 then
			local r = {}
			for i = 1, math.min(8, #list) do r[i] = tostring(list[i]) end
			r.n = #list
			return r
		end
		return tostring(v)
	end
	return v
end
local lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer()))
local seen = 0
for _, L in ipairs(lines) do
	local modes = CC.lineModes(L)
	local isTrain = false
	for _, m in ipairs(modes) do if m == 7 or m == 8 then isTrain = true end end
	if isTrain and seen < 2 then
		seen = seen + 1
		local s1 = CC.lineStops(L)[1]
		local p = CC.posOf(s1.stationGroup)
		local n = 0
		for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(p.x, p.y), 700, CT.BASE_EDGE))) do
			if n >= 8 then break end
			local be = CC.comp(e, CT.BASE_EDGE)
			local item = { id = e, line = CC.nameOf(L), inConstruction = CC.inConstruction and CC.inConstruction(e) or nil }
			for _, f in ipairs({ "type", "roadTemplate", "streetType", "trackType", "catenary", "typeIndex", "objects",
				"node0", "node1", "tangent0", "position0" }) do
				item[f] = field(be, f)
			end
			for name, ok in pairs(out.ctNames) do
				if ok then
					local okC, c = pcall(api.engine.getComponent, e, CT[name])
					if okC and c then
						item["has_" .. name] = true
						if name ~= "BASE_EDGE" then
							for _, f in ipairs({ "trackType", "catenary", "streetType", "hasBus", "tramTrackType" }) do
								local v = field(c, f)
								if v ~= nil and v ~= "ERR" then item[name .. "." .. f] = v end
							end
						end
					end
				end
			end
			out.edges[#out.edges + 1] = item
			n = n + 1
		end
	end
end
-- segnali: entita' con componente SIGNAL_LIST (se esiste)
pcall(function()
	if CT.SIGNAL_LIST then out.signalLists = #CC.each(api.engine.getEntitiesWithComponent(CT.SIGNAL_LIST)) end
end)
return out

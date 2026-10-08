-- SONDA 30 (sola lettura, 08.10.2026): s28 ha trovato 210 binari con be.objects:size() > 0 ma :at(1) non da' nulla
-- e pairs(api.type.ComponentType) non elenca piu' i nomi (40420). Qui si leggono gli oggetti in tutti i modi.
local CT = api.type.ComponentType
local GUESS = { "SIGNAL_LIST", "SIGNAL", "MODEL_INSTANCE_LIST", "TRANSPORT_NETWORK", "NAME", "BASE_EDGE", "BASE_NODE",
	"BASE_EDGE_TRACK", "BASE_EDGE_STREET", "BASE_EDGE_OBJECT", "EDGE_OBJECT", "WAYPOINT", "CONSTRUCTION", "PLAYER_OWNED",
	"TRACK_SIGNAL", "SIGNAL_STATE", "STATION", "BOUNDING_VOLUME", "LOD_LIST", "TERMINAL" }
local out = { ctEsistono = {}, edges = {} }
for _, n in ipairs(GUESS) do out.ctEsistono[n] = tostring(CT[n]) end
local function s(v) return tostring(v):sub(1, 120) end
local function tryAll(v)
	local r = { tostr = s(v), tipo = type(v) }
	for _, f in ipairs({ 1, 2, 0, "first", "second", "entity", "edge", "type", "x", "y", "param", "left", "oneWay" }) do
		pcall(function() local x = v[f]; if x ~= nil then r["f_" .. tostring(f)] = s(x) end end)
	end
	pcall(function() for k, x in pairs(v) do r["p_" .. tostring(k)] = s(x) end end)
	return r
end
local ids = { 348253, 292782 }
pcall(function()
	local b = CC.mapBox()
	for gx = b.minX + 1000, b.maxX, 1800 do
		for gy = b.minY + 1000, b.maxY, 1800 do
			if #ids >= 8 then break end
			pcall(function()
				for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1300, CT.BASE_EDGE))) do
					if #ids < 8 and e ~= 348253 and e ~= 292782 then
						local be = CC.comp(e, CT.BASE_EDGE)
						local n = 0
						pcall(function() n = be.objects:size() end)
						if n > 0 and tostring(be.roadTemplate):find("/track/", 1, true) then ids[#ids + 1] = e end
					end
				end
			end)
		end
	end
end)
for _, e in ipairs(ids) do
	local be = CC.comp(e, CT.BASE_EDGE)
	local item = { edge = e, objectsTostr = s(be.objects), elems = {} }
	pcall(function() item.size = be.objects:size() end)
	for _, how in ipairs({ "at0", "at1", "idx1", "idx0" }) do
		local ok, o = pcall(function()
			if how == "at0" then return be.objects:at(0) elseif how == "at1" then return be.objects:at(1)
			elseif how == "idx1" then return be.objects[1] else return be.objects[0] end
		end)
		item.elems[how] = ok and tryAll(o) or ("ERR " .. s(o))
		if ok and o ~= nil then
			local ent
			pcall(function() ent = o[1] end)
			if type(ent) ~= "number" then pcall(function() ent = o.first end) end
			if type(ent) ~= "number" then pcall(function() ent = o.entity end) end
			if type(ent) == "number" and not item.entity then
				item.entity = ent
				item.entComps = {}
				for _, n in ipairs(GUESS) do
					if CT[n] then
						local okC, c = pcall(api.engine.getComponent, ent, CT[n])
						if okC and c then
							local d = tryAll(c)
							pcall(function() d.fileName = s(c.fileName) end)
							pcall(function()
								local sigs = c.signals
								d.signalsSize = sigs:size()
								local s1 = sigs:at(1) or sigs[1]
								d.signal1 = tryAll(s1)
							end)
							pcall(function()
								local mi = c.models or c.modelInstances
								d.modelsSize = mi:size()
							end)
							item.entComps[n] = d
						end
					end
				end
			end
		end
	end
	out.edges[#out.edges + 1] = item
end
return out

-- SONDA 31 (sola lettura, 08.10.2026): campi dei SEGNALI. s30: be.objects e' una tabella Lua { {entita', tipo} }
-- (tipo 2 = segnale); l'entita' ha SIGNAL_LIST (26), EDGE_OBJECT (88, campo param), MODEL_INSTANCE_LIST (57).
-- Qui: campi di questi componenti (nomi provati), modelli usati e statistiche su TUTTI i segnali della mappa.
local CT = api.type.ComponentType
local function s(v) return tostring(v):sub(1, 140) end
local function fields(v, list)
	local r = {}
	for _, f in ipairs(list) do pcall(function() local x = v[f]; if x ~= nil then r[f] = s(x) end end) end
	return r
end
local EO_F = { "edgeEntity", "edge", "param", "left", "oneWay", "type", "model", "modelId", "playerEntity", "owner",
	"objectType", "dir", "direction", "signalType", "isLeft", "isOneWay", "name", "fileName" }
local SL_F = { "signals", "signal", "state", "type", "edgePr", "stateTime", "types", "oneWay" }
local SG_F = { "edgePr", "type", "state", "stateTime", "oneWay", "left", "param", "signalType", "entity", "index",
	"edge", "dir", "direction", "model", "modelId" }
local MI_F = { "fatInstances", "thinInstances", "instances", "models" }
local FI_F = { "modelId", "transf", "model", "id" }
local function modelName(id)
	local n
	pcall(function() n = api.res.modelRep.getName(id) end)
	return n and s(n) or nil
end
local out = { esempi = {}, stat = { segnali = 0, oneWay = {}, left = {}, tipoOggetto = {}, modelli = {}, tipiSegnale = {} } }
local seen = {}
pcall(function()
	local b = CC.mapBox()
	for gx = b.minX + 1000, b.maxX, 1800 do
		for gy = b.minY + 1000, b.maxY, 1800 do
			pcall(function()
				for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(gx, gy), 1300, CT.BASE_EDGE))) do
					if not seen[e] then
						seen[e] = true
						local be = CC.comp(e, CT.BASE_EDGE)
						if be and type(be.objects) == "table" and #be.objects > 0 then
							for _, o in ipairs(be.objects) do
								local ent, typ = o[1], o[2]
								out.stat.tipoOggetto[tostring(typ)] = (out.stat.tipoOggetto[tostring(typ)] or 0) + 1
								out.stat.segnali = out.stat.segnali + 1
								local eo = CC.comp(ent, CT.EDGE_OBJECT)
								local sl = CC.comp(ent, CT.SIGNAL_LIST)
								local mi = CC.comp(ent, CT.MODEL_INSTANCE_LIST)
								local eoF = eo and fields(eo, EO_F) or {}
								out.stat.oneWay[tostring(eoF.oneWay)] = (out.stat.oneWay[tostring(eoF.oneWay)] or 0) + 1
								out.stat.left[tostring(eoF.left)] = (out.stat.left[tostring(eoF.left)] or 0) + 1
								local mname
								pcall(function()
									local fi = mi.fatInstances
									local f1 = (type(fi) == "table") and fi[1] or fi:at(1)
									mname = modelName(f1.modelId)
								end)
								if eoF.model then mname = mname or modelName(tonumber(eoF.model)) or eoF.model end
								out.stat.modelli[tostring(mname)] = (out.stat.modelli[tostring(mname)] or 0) + 1
								local sg1
								pcall(function()
									local sigs = sl.signals
									local x = (type(sigs) == "table") and sigs[1] or sigs:at(1)
									sg1 = fields(x, SG_F)
									pcall(function() sg1.edgePrE = s(x.edgePr.entity); sg1.edgePrI = s(x.edgePr.index) end)
									pcall(function() sg1.nSignals = type(sigs) == "table" and #sigs or sigs:size() end)
								end)
								if sg1 then
									local k = tostring(sg1.type)
									out.stat.tipiSegnale[k] = (out.stat.tipiSegnale[k] or 0) + 1
								end
								if #out.esempi < 6 then
									local miF = mi and fields(mi, MI_F) or {}
									local fiF
									pcall(function()
										local fi = mi.fatInstances
										local f1 = (type(fi) == "table") and fi[1] or fi:at(1)
										fiF = fields(f1, FI_F)
										pcall(function() local t = f1.transf; fiF.pos = string.format("%.1f %.1f %.1f", t[13], t[14], t[15]) end)
									end)
									out.esempi[#out.esempi + 1] = { edge = e, entity = ent, tipo = typ, edgeObject = eoF,
										signalList = sl and fields(sl, SL_F) or nil, signal1 = sg1, modelList = miF, fat1 = fiF, modello = mname,
										template = s(be.roadTemplate), node0 = be.node0, node1 = be.node1,
										p0 = string.format("%.1f %.1f %.1f", be.position0.x, be.position0.y, be.position0.z),
										p1 = string.format("%.1f %.1f %.1f", be.position1.x, be.position1.y, be.position1.z) }
								end
							end
						end
					end
				end
			end)
		end
	end
end)
pcall(function() out.enumEdgeObjectType = {}; for k, v in pairs(api.type.enum.EdgeObjectType) do out.enumEdgeObjectType[s(k)] = s(v) end end)
pcall(function() out.enumSignalType = {}; for k, v in pairs(api.type.enum.SignalType) do out.enumSignalType[s(k)] = s(v) end end)
return out

-- SONDA 32 (sola lettura, 08.10.2026): segnali FERROVIARI (signal_path_*.mdl) della partita di terzi, con verso.
-- s31: be.objects = { {entita', tipo} } (tipo 2 = segnale, 0/1 = fermate stradali sx/dx); SIGNAL_LIST.signals[1] ha
-- type (0/1), state, stateTime, edgePr (tabella); EDGE_OBJECT.param; modello in MODEL_INSTANCE_LIST.fatInstances[1].
local CT = api.type.ComponentType
local function s(v) return tostring(v):sub(1, 140) end
local function mname(id) local n; pcall(function() n = api.res.modelRep.getName(id) end); return n and s(n) or "?" end
local out = { esempi = {}, perModelloTipo = {}, edgePr2 = {}, coppie = {} }
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
						if be and type(be.objects) == "table" and #be.objects > 0 and tostring(be.roadTemplate):find("/track/", 1, true) then
							local nSig = 0
							for _, o in ipairs(be.objects) do
								if o[2] == 2 then
									nSig = nSig + 1
									local ent = o[1]
									local eo = CC.comp(ent, CT.EDGE_OBJECT)
									local sl = CC.comp(ent, CT.SIGNAL_LIST)
									local mi = CC.comp(ent, CT.MODEL_INSTANCE_LIST)
									local m, pos, rot = "?", nil, nil
									pcall(function()
										local f1 = mi.fatInstances[1]
										m = mname(f1.modelId)
										local t = f1.transf
										pos = { t[13], t[14], t[15] }
										rot = { t[1], t[2] }
									end)
									local sg = sl and sl.signals and sl.signals[1]
									local ty = sg and sg.type
									local ep = {}
									pcall(function() for k, v in pairs(sg.edgePr) do ep[s(k)] = s(v) end end)
									local key = m:gsub("^.*/", "") .. " type=" .. tostring(ty)
									out.perModelloTipo[key] = (out.perModelloTipo[key] or 0) + 1
									pcall(function() local k2 = tostring(ep["2"]); out.edgePr2[k2] = (out.edgePr2[k2] or 0) + 1 end)
									if #out.esempi < 14 then
										local p0, p1 = be.position0, be.position1
										local t0, t1 = be.tangent0, be.tangent1
										out.esempi[#out.esempi + 1] = { edge = e, entity = ent, modello = m, type = ty, nSignals = sl and #sl.signals,
											edgePr = ep, param = eo and eo.param, pos = pos and string.format("%.2f %.2f %.2f", pos[1], pos[2], pos[3]),
											rotXY = rot and string.format("%.3f %.3f", rot[1], rot[2]),
											p0 = string.format("%.2f %.2f %.2f", p0.x, p0.y, p0.z), p1 = string.format("%.2f %.2f %.2f", p1.x, p1.y, p1.z),
											t0 = string.format("%.2f %.2f", t0.x, t0.y), t1 = string.format("%.2f %.2f", t1.x, t1.y),
											node0 = be.node0, node1 = be.node1, template = s(be.roadTemplate):gsub("^.*/track/", "") }
									end
								end
							end
							if nSig > 1 and #out.coppie < 5 then out.coppie[#out.coppie + 1] = { edge = e, n = nSig } end
						end
					end
				end
			end)
		end
	end
end)
return out

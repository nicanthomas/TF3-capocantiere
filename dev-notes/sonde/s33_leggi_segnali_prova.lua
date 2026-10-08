-- SONDA 33 (sola lettura): binari vicino ai punti CC.PROBE_PTS (default: binari della p26/p27) con oggetti e segnali.
local CT = api.type.ComponentType
local out = {}
for _, mid in ipairs(CC.PROBE_PTS or { { 1541.5, -4354.4 }, { 1841.5, -4354.4 } }) do
	for _, e in ipairs(CC.each(api.engine.util.octree.findEntitiesInCircle(api.type.Vec2f.new(mid[1], mid[2]), 8, CT.BASE_EDGE))) do
		local be = CC.comp(e, CT.BASE_EDGE)
		local r = { edge = e, node0 = be.node0, node1 = be.node1, nObj = type(be.objects) == "table" and #be.objects or tostring(be.objects), objects = {} }
		if type(be.objects) == "table" then
			for _, o in ipairs(be.objects) do
				local sl = CC.comp(o[1], CT.SIGNAL_LIST)
				local s1 = sl and sl.signals and sl.signals[1]
				local x = { entity = o[1], tipo = o[2] }
				if s1 then x.type = s1.type; pcall(function() x.dir = tostring(s1.edgePr[2]) end) end
				local eo = CC.comp(o[1], CT.EDGE_OBJECT)
				if eo then x.param = eo.param end
				local mi = CC.comp(o[1], CT.MODEL_INSTANCE_LIST)
				pcall(function() local t = mi.fatInstances[1].transf; x.rot = string.format("%.2f %.2f", t[1], t[2]); x.pos = string.format("%.1f %.1f", t[13], t[14]) end)
				r.objects[#r.objects + 1] = x
			end
		end
		out[#out + 1] = r
	end
end
return out

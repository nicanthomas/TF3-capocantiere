-- SONDA 17 (sola lettura): schemi completi (CC.TEMPLATES) dalle costruzioni del salvataggio di terzi: file, parametri,
-- moduli come testo "slot=nome|variante" (la profondita' dei risultati e' limitata), ingombro (bounding box in
-- coordinate locali) e lati con acqua (porti e depositi navali).
local CT = api.type.ComponentType
local ids = { 180194, 140889, 160924, 271528, 180991, 99553, 127770, 228185, 302273, 380629, 351589, 327373, 326177, 383170 }
local out = {}
for _, con in ipairs(ids) do
	local c = CC.comp(con, CT.CONSTRUCTION)
	if c then
		local r = { id = con, name = CC.nameOf(con), file = tostring(c.fileName), params = {}, modules = {} }
		pcall(function()
			for k, v in pairs(c.params) do
				if k == "modules" then
					for slot, m in pairs(v) do r.modules[#r.modules + 1] = tostring(slot) .. "=" .. tostring(m.name) .. "|" .. tostring(m.variant) end
				elseif type(v) ~= "table" and type(v) ~= "userdata" then
					r.params[tostring(k)] = v
				end
			end
		end)
		table.sort(r.modules)
		local m = c.transf
		local cx, cy = m[13], m[14]
		local X, Y = { m[1], m[2] }, { m[5], m[6] }
		r.transf = string.format("%.4f %.4f %.4f %.4f %.1f %.1f %.2f", m[1], m[2], m[5], m[6], m[13], m[14], m[15])
		pcall(function()
			local bv = CC.comp(con, CT.BOUNDING_VOLUME)
			local mn, mx = bv.bbox.min, bv.bbox.max
			r.bboxWorld = string.format("%.0f %.0f / %.0f %.0f (dx %.0f dy %.0f)", mn.x, mn.y, mx.x, mx.y, mx.x - mn.x, mx.y - mn.y)
		end)
		r.water = {}
		for _, d in ipairs({ 30, 60, 100 }) do
			r.water["+Y" .. d] = CC.onWater(cx + Y[1] * d, cy + Y[2] * d)
			r.water["-Y" .. d] = CC.onWater(cx - Y[1] * d, cy - Y[2] * d)
			r.water["+X" .. d] = CC.onWater(cx + X[1] * d, cy + X[2] * d)
			r.water["-X" .. d] = CC.onWater(cx - X[1] * d, cy - X[2] * d)
		end
		pcall(function() r.stations = #CC.each(c.stations); r.depots = #CC.each(c.depots) end)
		out[#out + 1] = r
	end
end
return out

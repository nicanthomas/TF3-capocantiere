-- SONDA 29 (sola lettura, 08.10.2026): moduli COMPLETI della stazione passeggeri grande della partita di terzi
-- (id 240991, 8 binari, 282 moduli: s24 la tronca) e parametri di tutte le modular_station (binari/lunghezza/quota).
local CT = api.type.ComponentType
local out = { grande = {}, stazioni = {} }
pcall(function()
	local c = api.engine.getComponent(240991, CT.CONSTRUCTION)
	out.grande.file = tostring(c.fileName)
	local mods = {}
	pcall(function() for slot, m in pairs(c.params.modules) do mods[#mods + 1] = tostring(slot) .. "=" .. tostring(m.name):gsub("^.*/modular_station/", "") .. "|" .. tostring(m.variant) end end)
	table.sort(mods)
	out.grande.modules = mods
end)
pcall(function()
	for _, e in ipairs(CC.each(api.engine.getEntitiesWithComponent(CT.CONSTRUCTION))) do
		local c = CC.comp(e, CT.CONSTRUCTION)
		if c and tostring(c.fileName):find("modular_station.con", 1, true) then
			local p = {}
			pcall(function() for k, v in pairs(c.params) do if type(v) ~= "table" and type(v) ~= "userdata" then p[tostring(k)] = v end end end)
			local z, h
			pcall(function() z = c.transf[15]; h = CC.heightAt(c.transf[13], c.transf[14]) end)
			out.stazioni[#out.stazioni + 1] = { id = e, tracks = p.tracks, length = p.length, spec = p.specialization,
				trackType = p.trackType, catenary = p.catenary, dz = (z and h) and math.floor((z - h) * 10) / 10 or nil }
		end
	end
end)
return out

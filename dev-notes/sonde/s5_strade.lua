-- SONDA 5 (sola lettura): tipi di strada (autostrade, extraurbane, sensi unici, rampe) con tipo, anno e corsie.
local out = {}
for _, n in ipairs(CC.each(api.res.streetTemplateRep.getAll())) do
	local s = tostring(n)
	if not s:find("/track/") and not s:find("trainstation") then
		local l = s:lower()
		if l:find("highway") or l:find("motorway") or l:find("country") or l:find("one_way") or l:find("large") or l:find("interchange") or l:find("ramp") then
			local info = s
			pcall(function()
				local t = api.res.streetTemplateRep.get(api.res.streetTemplateRep.find(s))
				info = info .. " | tipo " .. tostring(t.roadType) .. " | dal " .. tostring(t.availability and t.availability.yearFrom) .. " | corsie " .. tostring(#CC.each(t.laneConfigs))
			end)
			out[#out + 1] = info
		end
	end
end
table.sort(out)
return out

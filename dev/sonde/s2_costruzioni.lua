-- SONDA 2 (sola lettura): costruzioni disponibili per aerei, elicotteri, navi, merci, autostrade + i loro parametri.
local out = { list = {}, params = {} }
local words = { "air", "heli", "water", "harbor", "harbour", "port", "ship", "cargo", "freight", "highway", "motorway", "truck", "warehouse" }
local function wanted(n)
	n = n:lower()
	for _, w in ipairs(words) do if n:find(w, 1, true) then return true end end
	return false
end
for _, name in pairs(api.res.constructionRep.getAll()) do
	local n = tostring(name)
	if wanted(n) then out.list[#out.list + 1] = n end
end
table.sort(out.list)
for _, n in ipairs(out.list) do
	if n:find("^::/stations/") or n:find("^::/depots/") then
		pcall(function()
			local c = api.res.constructionRep.get(api.res.constructionRep.find(n))
			local t = {}
			for _, p in ipairs(CC.each(c.params)) do
				local vals = {}
				pcall(function() for _, v in ipairs(CC.each(p.values)) do vals[#vals + 1] = tostring(v) end end)
				t[#t + 1] = tostring(p.key) .. ": " .. table.concat(vals, ",") .. " (def " .. tostring(p.defaultIndex) .. ")"
			end
			pcall(function() t.year = c.availability and (tostring(c.availability.yearFrom) .. "-" .. tostring(c.availability.yearTo)) end)
			out.params[n] = t
		end)
	end
end
return out

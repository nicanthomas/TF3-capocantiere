-- SONDA 3 (sola lettura): moduli per stazioni merci, porti, aeroporti, eliporti.
local out = {}
local words = { "cargo", "freight", "harbor", "harbour", "water", "air", "heli", "runway", "terminal", "taxi", "warehouse" }
for _, n in ipairs(CC.each(api.res.moduleRep.getAll())) do
	local s = tostring(n)
	local l = s:lower()
	for _, w in ipairs(words) do
		if l:find(w, 1, true) then out[#out + 1] = s; break end
	end
end
table.sort(out)
return out

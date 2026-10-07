-- PULIZIA: toglie le piazzole elicotteri rimaste dalla prima prova p19 fallita.
local out = {}
for _, c in ipairs({ 146104, 335813 }) do out[#out + 1] = { id = c, removed = CC.removeConstruction(c) } end
return out

-- PROVA 39: perche' p38 fallisce? Stesse linee di p14, un segnale per binario con varianti diverse.
local CT = api.type.ComponentType
local edges = { 90240, 90053, 90160, 89969, 89950, 89625, 89877, 89870, 89813, 89685, 89809, 89892, 89861, 89697, 89761,
	90377, 89788, 89904, 89914, 89694, 89758, 90085, 90401, 89796, 89688, 89691, 90527, 90528, 84965, 89648, 89649, 89650, 90189 }
local live = {}
for _, e in ipairs(edges) do
	local be = CC.comp(e, CT.BASE_EDGE)
	if be and tostring(be.roadTemplate):find("/track/", 1, true) then
		local len = math.sqrt((be.position1.x - be.position0.x) ^ 2 + (be.position1.y - be.position0.y) ^ 2)
		local nobj = 0
		pcall(function() nobj = #be.objects end)
		live[#live + 1] = { e = e, len = len, ty = be.type, ti = be.typeIndex, nobj = nobj, inCon = CC.inConstruction(e), tmpl = tostring(be.roadTemplate):gsub("^.*/", "") }
	end
end
table.sort(live, function(a, b) return a.len > b.len end)
local out = { edges = {} }
for i = 1, math.min(6, #live) do local x = live[i]; out.edges[i] = string.format("%d len %.0f ty %d ti %d obj %d inCon %s %s", x.e, x.len, x.ty, x.ti, x.nobj, tostring(x.inCon), x.tmpl) end
local variants = { { oneWay = true, left = false }, { oneWay = false, left = false } }
out.res = {}
local k = 0
for i = 1, #live do
	local x = live[i]
	if x.ty == 0 and k < #variants then
		k = k + 1
		local v = variants[k]
		local ok, r = CC.placeSignals({ { edge = x.e, param = 0.5, oneWay = v.oneWay, left = v.left } })
		out.res[#out.res + 1] = string.format("edge %d oneWay %s left %s -> %s %s", x.e, tostring(v.oneWay), tostring(v.left), tostring(ok), tostring(r and (r.error or r.signals)):sub(1, 60))
	end
end
return out

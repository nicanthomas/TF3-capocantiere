-- SONDA 37 (sola lettura, punto 4c): qualita'/puntualita' delle consegne (novita' TF3). Funzioni trovate il 09.10.2026
-- in api.engine.util.cargo / stock / industry. Industrie e linee merci delle prove p4, p14, p37.
local CT = api.type.ComponentType
local function dump(v, depth)
	depth = depth or 0
	local t = type(v)
	if t ~= "table" and t ~= "userdata" then return v end
	if depth > 3 then return tostring(v) end
	local r, n = {}, 0
	pcall(function() for k, x in pairs(v) do n = n + 1; if n <= 20 then r[tostring(k)] = dump(x, depth + 1) end end end)
	if n == 0 then
		pcall(function() local s = v:size(); r.size = s; for i = 1, math.min(s, 8) do r["at" .. i] = dump(v:at(i), depth + 1) end end)
		for _, f in ipairs({ "quality", "avgQuality", "goodQuality", "badQuality", "count", "amount", "total", "delay", "deliveryTime",
			"punctuality", "rating", "productivity", "production", "maxProduction", "targetProduction", "cargoType", "value",
			"good", "bad", "late", "onTime", "time", "age", "averageAge", "percentage" }) do
			pcall(function() local x = v[f]; if x ~= nil then r[f] = dump(x, depth + 1) end end)
		end
		if next(r) == nil then return tostring(v) end
	end
	return r
end
local function try(f, ...) local ok, r = pcall(f, ...); if ok then return dump(r) end return "ERR " .. tostring(r):sub(1, 120) end
local out = { lines = {}, industries = {} }
local C, S, I = api.engine.util.cargo, api.engine.util.stock, api.engine.util.industry
for _, L in ipairs({ 89641, 89873, 90082 }) do
	out.lines[tostring(L)] = { summ = try(C.getSummarizedCargoQualityDataForLine, L), full = try(C.getCargoQualityDataForLine, L) }
end
for _, ind in ipairs({ 52765, 62781, 61748, 62819 }) do
	local ic = CC.comp(ind, CT.INDUSTRY)
	local sl = ic and ic.stockList
	local r = { name = CC.nameOf(ind), stockList = sl }
	r.productivity = try(I.getIndustryProductivityInfo, ind)
	if sl then
		r.rating = try(S.getProductionRating, sl)
		r.quality = try(C.getSummarizedCargoQualityDataForStockList, sl)
		r.produced = try(S.getCargoProducedPerYear, sl)
		r.shipped = try(S.getCargoShippedPerYear, sl)
		r.delivered = try(S.getCargoDeliveredPerYear, sl)
		r.adjDelivery = try(S.getAdjustedDeliveryTime, sl)
	end
	out.industries[tostring(ind)] = r
end
pcall(function() out.closing = dump(I.getClosingIndustries()) end)
return out

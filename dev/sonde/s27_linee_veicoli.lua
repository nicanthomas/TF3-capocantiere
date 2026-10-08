-- SONDA 27 (sola lettura): come sono impostate le linee e i veicoli di una partita gia' costruita.
-- Per tutte le linee (max 120): modi, fermate, numero e modelli dei veicoli, lunghezza delle composizioni.
-- Per 4 linee (1 per modo diverso): campi completi della linea e di una fermata (impostazioni di carico/scarico,
-- attese, ecc.: novita' TF3 "pieno controllo su carico e scarico") e campi di un veicolo.
-- Inoltre: catalogo dei modelli di veicolo usati, con conteggio.
local CT = api.type.ComponentType
local out = { linee = {}, dettagli = {}, modelli = {} }
local function keys(t, max)
	local r = {}
	pcall(function() for k, v in pairs(t) do r[#r + 1] = tostring(k) .. "=" .. tostring(v):sub(1, 60); if #r >= (max or 60) then break end end end)
	table.sort(r)
	return r
end
local lines = {}
pcall(function() lines = CC.each(api.engine.system.lineSystem.getLinesForPlayer(api.engine.util.getPlayer())) end)
out.numero_linee = #lines
local modeSeen = {}
for i, L in ipairs(lines) do
	if i > 120 then break end
	local r = { id = L, name = CC.nameOf(L), modes = {}, models = {} }
	pcall(function() for m in pairs(api.engine.util.line.getLineTransportModesUnion(L)) do r.modes[#r.modes + 1] = m end end)
	table.sort(r.modes)
	pcall(function() r.stops = #CC.lineStops(L) end)
	local vs = {}
	pcall(function() vs = CC.lineVehicles(L) end)
	r.vehicles = #vs
	for k, v in ipairs(vs) do
		if k > 3 then break end
		pcall(function()
			local tv = CC.comp(v, CT.TRANSPORT_VEHICLE)
			local names = {}
			for _, part in ipairs(CC.each(tv.transportVehicleConfig.vehicles)) do
				local n = tostring(api.res.modelRep.getName(part.part.modelId))
				names[#names + 1] = n
				out.modelli[n] = (out.modelli[n] or 0) + 1
			end
			r.models[#r.models + 1] = (#names > 3) and (names[1] .. " + " .. (#names - 1) .. " x " .. names[2]) or table.concat(names, " + ")
		end)
	end
	out.linee[#out.linee + 1] = r
	local mk = table.concat(r.modes, ",")
	if not modeSeen[mk] and #out.dettagli < 4 and #vs > 0 then
		modeSeen[mk] = true
		local d = { line = L, name = r.name, modes = mk }
		pcall(function() d.line_fields = keys(CC.comp(L, CT.LINE)) end)
		pcall(function()
			local lc = CC.comp(L, CT.LINE)
			local st = CC.each(lc.stops)[1]
			d.stop_fields = keys(st)
			pcall(function() d.stop_constraints = keys(st.constraints) end)
			pcall(function() d.stop_loadMode = tostring(st.loadMode) end)
		end)
		pcall(function() d.vehicle_fields = keys(CC.comp(vs[1], CT.TRANSPORT_VEHICLE)) end)
		pcall(function() d.vehicle_info = keys(CC.comp(L, CT.LINE).vehicleInfo) end)
		out.dettagli[#out.dettagli + 1] = d
	end
end
return out

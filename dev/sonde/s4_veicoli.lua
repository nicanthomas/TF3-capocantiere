-- SONDA 4 (sola lettura): veicoli per cartella (/vehicle/<tipo>/); quelli disponibili quest'anno (esclusi treni,
-- carrozze, bus e camion, gia' noti) con modi di trasporto e capacita'.
local out = { year = CC.year(), folders = {}, avail = {} }
api.res.modelRep.forEachModelWithMetadata("transportVehicle", function(name)
	local folder = name:match("/vehicle/([^/]+)/") or "?"
	out.folders[folder] = (out.folders[folder] or 0) + 1
	local id = api.res.modelRep.find(name)
	local m = api.res.modelRep.get(id)
	local av = m.metadata.availability
	local from, to = av and av.yearFrom or 0, av and av.yearTo or 0
	if from <= out.year and (to == 0 or to > out.year) and folder ~= "train" and folder ~= "waggon" and folder ~= "bus" and folder ~= "truck" then
		local modes = {}
		pcall(function() for _, tm in ipairs(CC.each(m.metadata.transportVehicle.engineTransportModes)) do modes[#modes + 1] = tostring(tm) end end)
		local pass, other = CC.modelLoads(id)
		out.avail[#out.avail + 1] = table.concat({ folder, name, tostring(from), "modi " .. table.concat(modes, "/"), "pax " .. pass, "merci " .. other }, " | ")
	end
end)
table.sort(out.avail)
-- valori numerici dei modi di trasporto, per leggere "modi" qui sopra
out.TM = {}
pcall(function() for k, v in pairs(api.type.enum.TransportMode) do out.TM[tostring(k)] = v end end)
return out

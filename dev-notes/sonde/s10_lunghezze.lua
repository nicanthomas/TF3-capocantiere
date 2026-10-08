-- SONDA 10 (sola lettura, usa la verifica a secco della bozza: niente viene costruito): lunghezza dei veicoli e
-- stazioni di lunghezze e binari diversi -> CC.STATION_LENGTH_PARAMS, posizioni dei moduli, modelLength (b5).
-- Eseguire SENZA --solo-lib (serve la bozza).
local out = { models = {}, stations = {} }
local loco = CC.pickLocomotive(CC.railEra().catenary)
local car = CC.pickModel("waggon", { "boxcar", "bulk", "flatbed", "liquid", "univ", "bay" }, { passengers = true })
for _, m in ipairs({ loco, car }) do
	if m then
		local r = { name = m.name, modelLength = CC.modelLength(m.id) }
		pcall(function()
			local bi = api.res.modelRep.get(m.id).boundingInfo
			r.bbMin = { bi.bbMin.x, bi.bbMin.y, bi.bbMin.z }
			r.bbMax = { bi.bbMax.x, bi.bbMax.y, bi.bbMax.z }
		end)
		out.models[#out.models + 1] = r
	end
end
-- stazione di prova vicino alla prima citta': solo verifica a secco (makeProposalData)
local town = CC.each(api.engine.getEntitiesWithComponent(api.type.ComponentType.TOWN))[1]
local p = CC.posOf(town)
local function dry(layout, segments, lengthParam)
	local prop = api.type.SimpleProposal.new()
	local ce = api.type.SimpleProposal.ConstructionEntity.new()
	ce.fileName = "::/stations/rail/modular_station/modular_station.con"
	local nT = CC.layoutTracks(layout)
	ce.params = { year = CC.year(), seed = 0, modules = CC.railStationModulesN(nil, layout, segments, "passengers"), tracks = nT, length = lengthParam }
	ce.transf = api.type.Mat4f.new(api.type.Vec4f.new(0, -1, 0, 0), api.type.Vec4f.new(1, 0, 0, 0),
		api.type.Vec4f.new(0, 0, 1, 0), api.type.Vec4f.new(p.x + 800, p.y + 800, CC.heightAt(p.x + 800, p.y + 800) or 0, 1))
	ce.playerEntity = api.engine.util.getPlayer()
	prop.constructionsToAdd = { ce }
	local ok, info = CC.dryRun(prop)
	return { layout = layout, segments = segments, length = lengthParam, ok = ok, msg = info and (info.exception or table.concat(info.msg or {}, "; ")) }
end
for _, seg in ipairs({ 2, 3, 4, 6, 8 }) do
	for _, lp in ipairs({ seg - 2, seg - 1, seg }) do
		if lp >= 0 then out.stations[#out.stations + 1] = dry("PTTP", seg, lp) end
	end
end
for _, lay in ipairs({ "PT", "PTTPTP", "PTTPTTP", "PTTTTP" }) do out.stations[#out.stations + 1] = dry(lay, 4, 3) end
return out

-- PROVA 1 (sola lettura): cosa c'e' sulla mappa per le prove successive.
local pairT = T.townPair(1500, 6000, 3000)
local pairI = T.industryPair(1500, 7000)
return {
	year = CC.year(), speed = CC.gameSpeed(),
	townPair = pairT and { pairT[1].name, pairT[1].id, pairT[2].name, pairT[2].id, pairT.d },
	industryPair = pairI and { pairI.from.name, pairI.from.id, pairI.to.name, pairI.to.id, pairI.cargo, pairI.d },
	lines = T.lines(),
	cargoModules = (function() local m, e = CC.cargoStationModules(); return m and "trovati" or e end)(),
}

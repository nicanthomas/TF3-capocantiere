-- ---------------------------------------------------------------- casi di prova (vedi test_mock_pre.lua)
local fails, passes = 0, 0
local function check(cond, msg)
	if cond then passes = passes + 1 else fails = fails + 1; print("FALLITO: " .. msg) end
end

-- un'azione finta che "costruisce": stazione (costruzione), binario, strada, linea e veicolo
local function makeStuff()
	local con = newEnt({ CONSTRUCTION = { stations = V({}), depots = V({}), frozenNodes = V({}), frozenEdges = V({}) }, PLAYER_OWNED = { player = 7 } })
	local trk = newEnt({ BASE_EDGE = { roadTemplate = "::/infrastructure/track/standard/standard.street_template", node0 = 1, node1 = 2 } })
	local road = newEnt({ BASE_EDGE = { roadTemplate = "::/infrastructure/street/town/town_old_small.street_template", node0 = 3, node1 = 4 }, BASE_EDGE_STREET = {} })
	return { con, trk, road }
end
SIM_ACTIONS.fake_build = function(a)
	CC.send(api.cmd.makeWorldBuildProposalCmd({ make = makeStuff }))
	local L = newEnt({ LINE = { stops = V({}), vehicleInfo = { transportModes = { false, true } } } })
	CC.send({ kind = "noop" })            -- comando che non crea nulla
	local _, res = CC.send(api.cmd.makeVehicleBuyCmd(7, 1, { vehicles = {} }))
	if a.fail then return { ok = false, error = "fallita apposta" } end
	return { ok = true, line_id = L }
end
-- le azioni definite dopo b9 non sono avvolte: avvolgo a mano come fa b9
do
	local f = SIM_ACTIONS.fake_build
	SIM_ACTIONS.fake_build = function(a)
		CC.txBegin()
		local ok, r = pcall(f, a)
		local tx = CC.txEnd()
		r = ok and r or { ok = false, error = tostring(r) }
		r.created = CC.txClassify(tx)
		return r
	end
end

-- 1) registro: costruzione, binario, strada e veicolo classificati (la linea non passa da CC.send in questo finto)
local r = SIM_ACTIONS.fake_build({})
check(r.ok, "fake_build ok")
check(#r.created.constructions == 1, "1 costruzione registrata (" .. #r.created.constructions .. ")")
check(#r.created.tracks == 1, "1 binario registrato")
check(#r.created.roads == 1, "1 strada registrata")
check(#r.created.vehicles == 1, "1 veicolo registrato")
check(#CC._txStack == 0, "registro chiuso dopo l'azione")

-- 2) annulla: vende il veicolo, rimuove costruzione e binario, NON la strada
local created = r.created
local road = created.roads[1]
local u = SIM_ACTIONS.undo({ created = created })
check(u.ok, "undo ok")
check(#W.sold == 1, "veicolo venduto")
-- a fasi: 1) veicoli e linee, 2) binari, 3) costruzioni (togliere tutto insieme fa crashare il gioco)
check(#W.removedCons == 0 and #W.removedEdges == 0 and u.done == false, "fase 1: solo veicoli e linee")
local u2 = SIM_ACTIONS.undo({ created = created })
check(#W.removedEdges == 1 and W.removedEdges[1] == created.tracks[1] and #W.removedCons == 0, "fase 2: solo il binario rimosso")
local u3 = SIM_ACTIONS.undo({ created = created })
check(#W.removedCons == 1 and u3.done == true, "fase 3: costruzione rimossa")
check(W.comps[road] ~= nil, "la strada resta")

-- 3) registri annidati: l'azione esterna vede anche quello che costruisce l'interna
CC.txBegin()
CC.send(api.cmd.makeWorldBuildProposalCmd({ make = makeStuff }))
CC.txBegin()
CC.send(api.cmd.makeWorldBuildProposalCmd({ make = makeStuff }))
local inner = CC.txEnd()
local outer = CC.txEnd()
check(#inner.ents == 3, "registro interno: 3 entita'")
check(#outer.ents == 6, "registro esterno: 6 entita' (" .. #outer.ents .. ")")

-- 4) pulizia dopo un fallimento (azione stradale avvolta da b9): build_bus_line con citta' inesistente
local rb = SIM_ACTIONS.build_bus_line({ town_id = 999999 })
check(rb.ok == false, "build_bus_line su citta' inesistente fallisce senza eccezioni")
check(type(rb.created) == "table", "anche un'azione fallita restituisce created")

-- 5) verifica a secco
local okD, info = CC.dryRun({ bad = true })
check(okD == false and info.critical == true, "dryRun: proposta non valida riconosciuta")
local okB, err = CC.buildCmd({ boom = true }, true)
check(okB == false and tostring(err):find("verifica"), "buildCmd: eccezione in verifica blocca l'invio anche con ignoreErrors")
local okG = CC.buildCmd({}, false)
check(okG == true, "buildCmd: proposta buona passa")

-- 6) controllo argomenti
check(pcall(CC.need, { town_ids = { 1, 2 } }, { town_ids = "ints", name = "str?" }), "need: argomenti giusti")
check(not pcall(CC.need, { town_ids = {} }, { town_ids = "ints" }), "need: lista vuota rifiutata")
check(not pcall(CC.need, { line_id = "3" }, { line_id = "int" }), "need: testo al posto di numero rifiutato")
local e1 = SIM_ACTIONS.add_vehicles({ count = 2 })
check(e1.ok == false and tostring(e1.error):find("line_id"), "add_vehicles senza line_id: errore leggibile (" .. tostring(e1.error) .. ")")

-- 7) aggiungi veicoli copiando la composizione di quello esistente
local depot = newEnt({ VEHICLE_DEPOT = { outNodes = V({ 11 }), inNodes = V({ 12 }) } })
local depCon = newEnt({ CONSTRUCTION = { depots = V({ depot }), stations = V({}), fileName = "road_depot.con" }, PLAYER_OWNED = { player = 7 },
	BOUNDING_VOLUME = { bbox = { min = { x = 0, y = 0, z = 0 }, max = { x = 10, y = 10, z = 0 } } } })
local st = newEnt({ STATION = { terminals = V({ { vehicleNodeId = 55 } }) }, BOUNDING_VOLUME = { bbox = { min = { x = 0, y = 0, z = 0 }, max = { x = 2, y = 2, z = 0 } } } })
local grp = newEnt({ STATION_GROUP = { stations = V({ st }) } })
local L2 = newEnt({ LINE = { stops = V({ { stationGroup = grp }, { stationGroup = grp } }), vehicleInfo = { transportModes = { false, true } } } })
newEnt({ TRANSPORT_VEHICLE = { line = L2, transportVehicleConfig = { vehicles = V({ { part = { modelId = 501 } }, { part = { modelId = 502 } } }) } } })
local ra = SIM_ACTIONS.add_vehicles({ line_id = L2, count = 2 })
check(ra.ok, "add_vehicles ok (" .. tostring(ra.error) .. ")")
check(#CC.lineVehicles(L2) == 3, "la linea ha 3 veicoli (" .. #CC.lineVehicles(L2) .. ")")
local models = CC.vehicleModels(CC.lineVehicles(L2)[3])
check(#models == 2 and models[1] == 501 and models[2] == 502, "stessa composizione copiata")
check(ra.depot_id == depot, "deposito trovato")

-- 8) togli veicoli: ne resta almeno uno
local rr = SIM_ACTIONS.remove_vehicles({ line_id = L2, count = 5 })
check(rr.ok and rr.sold == 2 and rr.left == 1, "remove_vehicles: venduti 2, resta 1")

-- 9) cancella linea: vende i veicoli e poi distrugge la linea
local rd = SIM_ACTIONS.delete_line({ line_id = L2 })
check(rd.ok and #W.destroyedLines == 1, "delete_line ok")

-- 10) piano delle stazioni (b5)
local p1 = CC.planStation({ kind = "passengers", trains = 1, lines = 1, train_len = 100 })
check(p1.tracks == 1 and p1.through == 0 and p1.layout == "PT", "1 treno: binario unico (" .. p1.layout .. ")")
check(p1.segments == 3 and p1.length == 120, "treno da 100 m: stazione da 120 m (" .. p1.length .. ")")
local p2 = CC.planStation({ kind = "passengers", trains = 2, lines = 1, train_len = 150 })
check(p2.tracks == 2 and p2.layout == "PTTP", "2 treni: 2 binari per incrociarsi")
check(p2.segments == 4, "treno da 150 m: 4 pezzi (160 m)")
local p3 = CC.planStation({ kind = "passengers", trains = 4, lines = 2, double = true, through = 1, terminal = true, train_len = 200 })
check(p3.tracks == 3 and p3.through == 2, "doppio binario, capolinea con 4 treni, transito: 3 + 2 (" .. p3.tracks .. " + " .. p3.through .. ")")
local p4 = CC.planStation({ kind = "cargo", trains = 3, cargo_types = 2 })
check(p4.tracks == 1 and p4.segments == 4 and p4.layout == "PT", "scalo: sempre 1 binario da 160 m (schema verificato)")
local p5 = CC.planStation({ kind = "cargo", trains = 4, cargo_types = 1 })
check(p5.tracks == 1 and #p5.notes == 1, "scalo: 1 merce, 4 treni -> 1 binario + avviso binario d'attesa")
local p6 = CC.planStation({ kind = "passengers", trains = 20, lines = 9, double = true, through = 1, max_tracks = 8 })
check(p6.tracks + p6.through <= 8, "mai piu' di max_tracks binari")
-- disposizione: ogni binario ha un marciapiede accanto
for k = 1, 6 do
	local lay = CC.stationLayout(k, 0)
	local okLay = CC.layoutTracks(lay) == k
	for c = 1, #lay do
		if lay:sub(c, c) == "T" and lay:sub(c - 1, c - 1) ~= "P" and lay:sub(c + 1, c + 1) ~= "P" then okLay = false end
	end
	check(okLay, "disposizione con " .. k .. " binari: " .. lay)
end
local off = CC.moduleOffsets(4)
check(off[1] == -10 and off[4] == 20, "posizioni dei pezzi per 160 m come la stazione copiata")
check(#CC.moduleOffsets(6) == 6 and CC.moduleOffsets(6)[1] == -20, "posizioni per 6 pezzi")
check(CC.stationLengthParam(4) == 3, "parametro length 160 m = 3 (verificato)")
check(CC.expectedEnds({ layout = "PTTP" }, { f = true, b = false }) == 3, "estremi attesi: un lato unito, uno no")
check(CC.staggerStop(1, 3, 6) == 0 and CC.staggerStop(2, 3, 6) == 2 and CC.staggerStop(3, 3, 6) == 4, "treni distribuiti lungo la linea")
check(CC.fitCars(nil, nil, 10, 120) == 3, "treno accorciato per stare nel marciapiede (" .. CC.fitCars(nil, nil, 10, 120) .. ")")

-- 11) ordine delle fermate e anello (b6, b7)
local bf = CC.lineStopOrder({ 1, 2, 3, 4 }, "back_forth")
check(table.concat(bf, ",") == "1,2,3,4,3,2", "avanti e indietro: " .. table.concat(bf, ","))
check(table.concat(CC.lineStopOrder({ 1, 2 }, "back_forth"), ",") == "1,2", "avanti e indietro con 2 fermate")
check(table.concat(CC.lineStopOrder({ 1, 2, 3, 4 }, "ring_reverse"), ",") == "1,4,3,2", "anello al contrario")
local pts = { { x = 0, y = 0 }, { x = 10, y = 10 }, { x = 10, y = 0 }, { x = 0, y = 10 } }
local ord = CC.orderRing(pts)
local function tour(o) local L = 0 for i = 1, #o do local a, b = pts[o[i]], pts[o[i % #o + 1]] L = L + math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end return L end
check(ord[1] == 1 and math.abs(tour(ord) - 40) < 1e-6, "anello senza incroci (giro di 40, ordine " .. table.concat(ord, ",") .. ")")

-- 12) controllo argomenti nuovi tipi e azioni vecchie (b1, b9)
check(not pcall(CC.need, { x = 1 }, { x = "bool" }), "need: bool richiesto")
check(pcall(CC.need, { x = true }, { x = "bool?" }), "need: bool ok")
check(not pcall(CC.need, { t = 424242 }, { t = "id" }), "need: entita' inesistente rifiutata")
check(not pcall(CC.need, { n = 2.5 }, { n = "int" }), "need: decimale rifiutato dove serve un intero")
local rv = SIM_ACTIONS.build_bus_line({ town_id = "101" })
check(rv.ok == false and tostring(rv.error):find("town_id"), "azione vecchia: argomento sbagliato fermato nella mod (" .. tostring(rv.error) .. ")")
local rp = SIM_ACTIONS.create_line_from_stations({ station_ids = { grp, grp }, pattern = "zigzag" })
check(rp.ok == false and tostring(rp.error):find("pattern"), "linea da stazioni: pattern sconosciuto rifiutato")

-- 13) collaudo di una linea (b8): bacino vuoto e veicolo fermo al secondo controllo
local stB = newEnt({ STATION = { terminals = V({ { vehicleNodeId = 56 } }) }, BOUNDING_VOLUME = { bbox = { min = { x = 0, y = 0, z = 0 }, max = { x = 2, y = 2, z = 0 } } } })
local grpB = newEnt({ STATION_GROUP = { stations = V({ stB }) } })
local L3 = newEnt({ LINE = { stops = V({ { stationGroup = grp }, { stationGroup = grpB } }), vehicleInfo = { transportModes = { false, true } } } })
local v3 = newEnt({ TRANSPORT_VEHICLE = { line = L3, state = 1, transportVehicleConfig = { vehicles = V({ { part = { modelId = 501 } } }) } },
	BOUNDING_VOLUME = { bbox = { min = { x = 50, y = 50, z = 0 }, max = { x = 52, y = 52, z = 0 } } } })
local c1 = CC.checkLine(L3)
check(c1.ok == false and c1.vehicles == 1 and c1.stops == 2, "collaudo: linea letta (veicoli " .. tostring(c1.vehicles) .. ")")
local foundCatch = false
for _, pr in ipairs(c1.problems) do if pr:find("bacino") then foundCatch = true end end
check(foundCatch, "collaudo: fermate senza bacino segnalate")
check(c1.movement_unknown == 1, "collaudo: primo controllo, movimento non ancora verificabile")
W.comps[WORLD].GAME_TIME.gameTime = 9000
local c2 = CC.checkLine(L3)
check(c2.vehicles_still == 1, "collaudo: secondo controllo, veicolo fermo riconosciuto")
W.comps[v3].BOUNDING_VOLUME.bbox = { min = { x = 150, y = 50, z = 0 }, max = { x = 152, y = 52, z = 0 } }
W.comps[WORLD].GAME_TIME.gameTime = 12000
local c3 = CC.checkLine(L3)
check(c3.vehicles_moving == 1 and c3.vehicles_still == 0, "collaudo: veicolo che si e' mosso")
local cn = SIM_ACTIONS.check_network({})
check(cn.ok == true and type(cn.lines_with_problems) == "table", "controlla la rete: risponde anche senza linee del giocatore")

-- flotta iniziale stimata alla creazione delle linee (calcolo puro)
do
	local n1, f1 = CC.estimateFleet({ { x = 0, y = 0 }, { x = 6000, y = 0 } }, nil, "bus")
	-- 12000 m * 1.35 / (22 * 0.65) = 1132.9 s + 2 * 25 = 1182 s -> 1182 / 240 = 4.9 -> 5 bus
	check(n1 == 5 and f1.round_trip_s == 1182 and f1.estimated, "flotta: 6 km tra due citta' -> 5 bus (" .. n1 .. ", " .. f1.round_trip_s .. " s)")
	local n2 = CC.estimateFleet({ { x = 0, y = 0 }, { x = 300, y = 0 } }, nil, "bus")
	check(n2 == 1, "flotta: linea cortissima -> almeno 1 veicolo (" .. n2 .. ")")
	local n3, f3 = CC.estimateFleet({ { x = 0, y = 0 }, { x = 200000, y = 0 } }, nil, "bus")
	check(n3 == CC.FLEET_MAX.bus and f3.max == CC.FLEET_MAX.bus, "flotta: linea lunghissima limitata al massimo (" .. n3 .. ")")
	local n4, f4 = CC.estimateFleet({ { x = 0, y = 0 }, { x = 6000, y = 0 } }, 44, "bus")
	check(n4 == 3 and f4.speed_from_model, "flotta: veicolo piu' veloce (velocita' del modello) -> meno veicoli (" .. n4 .. ")")
	local n5, f5 = CC.initialFleet({ 1, 2 }, nil, "bus", 7, 6)
	check(n5 == 6 and f5.estimated == false, "flotta: il numero chiesto vince sulla stima, nei limiti (" .. n5 .. ")")
	check(CC.modelTopSpeed(12345) == nil, "flotta: velocita' del modello assente -> nil, senza errori")
end

print(string.format("RISULTATO: %d ok, %d falliti", passes, fails))

-- Un mock fallito deve rendere rossa la CI, non soltanto stampare un avviso.
if fails > 0 then error(string.format("Mock Lua: %d controlli falliti", fails)) end

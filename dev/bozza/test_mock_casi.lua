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
check(#W.removedCons == 1, "costruzione rimossa")
check(#W.removedEdges == 1 and W.removedEdges[1] == created.tracks[1], "solo il binario rimosso")
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

print(string.format("RISULTATO: %d ok, %d falliti", passes, fails))

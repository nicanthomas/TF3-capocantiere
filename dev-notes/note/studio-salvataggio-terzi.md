# Studio di un salvataggio di terzi (07.10.2026)

Salvataggio scaricato dal hub delle mod da Nicolo', caricato con la mod Capo Cantiere v13 attiva.
Mappa olandese, anno 2082, 16 citta', 46 industrie, 94 linee, 240 stazioni, 165 depositi/officine.
Solo letture (sim_eval, DEV_MODE): nulla e' stato costruito ne' salvato. Risultati grezzi solo in locale (`dev-notes/risultati/`, troppo grandi per il repo).

## Rete trovata
- Linee: 60 su 94 con 2 fermate; le altre fino a 20 fermate (tram, bus urbani, aerei a 3 scali).
- Tutti i mezzi: treni (alta velocita' con catenaria), bus, tram, camion, aerei, elicotteri, navi, metropolitana
  (`underground_station.con`, mod di terzi). Veicoli: 234 in viaggio, 43 al capolinea.
- Costruzioni del giocatore piu' frequenti: officine stradali `road_maint_station.con` (112), fermate modulari
  `modular_terminal.con` (61), magazzini `warehouses/warehouse.con` (21), officine ferroviarie
  `rail_maint_station.con` (17), depositi bus `road_depot.con` (15), stazioni ferroviarie modulari (13).
- Binari: 1749 tratti alta velocita' con catenaria e 30 "simple" attorno alle stazioni; nessun oggetto (segnale) sui
  tratti vicini alle stazioni.

## Scoperte sull'API (build 40408)
- `api.engine.getEntitiesWithComponent(BASE_EDGE)` e' VIETATO ("Cannot loop over this component type"): per i
  segmenti si usa `octree.findEntitiesInCircle` (griglia di cerchi da 1450 m ogni 2000 m copre la mappa).
- `ComponentType.BASE_EDGE_TRACK` NON esiste. Un binario si riconosce da `BASE_EDGE.roadTemplate` che contiene
  `/infrastructure/track/` (es. `high_speed/high_speed_catenary.street_template`) e dall'assenza di
  `BASE_EDGE_STREET`. Esistono `EDGE_OBJECT`, `SIGNAL_LIST`, `MODEL_INSTANCE_LIST`, `TRANSPORT_NETWORK`.
- Modi di trasporto di una linea: `api.engine.util.line.getLineTransportModesUnion(L)` (chiavi = modi: bus 3+4,
  treno 7+8+14+15, aereo 9+11, tram 6+15). `LINE.vehicleInfo.transportModes[i]` ha indice = modo (non modo+1):
  la bozza sottraeva 1 e i controlli di percorso fallivano.
- Fermate: `Line.Stop` ha `stationGroup`, `station` e `terminal` (da 0). Nei gruppi con piu' stazioni (fermata bus
  davanti alla ferrovia) il nodo va preso da `stop.station`/`stop.terminal`, non dalla prima stazione del gruppo.
- `api.engine.util.line` offre anche: getLineProblems, getDetailedLineProblems (StopState per fermata),
  getLineIssues, getLineStationProblems, getNoRoadConnectionProblems, getMaxFrequency, getLineCapacityUsages,
  calcLineStationThroughput (numero), getFailedPathReason (argomenti da capire). Non esistono getFrequency/getRate.
- Lato simulazione `game.interface` e' nil.
- Tempo: `GAME_TIME.gameTime` in millisecondi (266117000); `api.util.getDefaultMonthDuration()` = 121750,
  `getDefaultDayDuration()` = 4000; `getMonthDuration()`/`getYearDuration()` vogliono argomenti;
  `api.engine.util.getCalendarDate()` esiste. Build: `api.util.getBuildVersion()` = "40408".
- Comandi di gioco: makeGameSetSpeedCmd, makeGameSetCalendarSpeedCmd, makeGameSetDateCmd, ... Nessun comando di
  salvataggio in `api.cmd`.
- Stato dei veicoli: `api.type.enum.TransportVehicleState` = IN_DEPOT 0, EN_ROUTE 1, AT_TERMINAL 2, GOING_TO_DEPOT 3.
- TF3 ha le OFFICINE (maint station) per strada, ferrovia e acqua oltre ai depositi; aeroporti ed eliporti hanno
  un deposito interno (campo `depots` della costruzione).
- Stazione ferroviaria modulare di esempio: `length = 5`, `tracks = 3`, `trackType = 3`, `catenary = 2`, 89 moduli.

## Collaudo (b8) provato su una rete che funziona
- Prima versione: 10 linee su 20 "con problemi", tutte false (percorsi, depositi, bacini).
- Corretto: modi dalla unione, nodo della fermata dalla linea, percorso tra gruppi (tutte le coppie di stazioni),
  bacino: una fermata senza edifici e' un nodo di scambio se il gruppo ha altre linee o c'e' un'altra stazione
  entro 250 m; problema solo se meno di 2 fermate servono a qualcosa.
- Risultato finale: 93 linee su 94 a posto; l'unica segnalata ("Hilversum - Fish") non ha davvero veicoli.

## Da fare con questi dati
- Riempire `CC.TEMPLATES` (aeroporto, campo d'aviazione, eliporto, porto, deposito navale) dalla sonda s17.
- Verificare dove stanno i segnali (questa rete non ne ha vicino alle stazioni): prova a mano su CC_test (s8).

# Scoperte sull'API di Transport Fever 3 (build 40408)

Verificate in gioco durante lo sviluppo. Dove c'e' scritto **CRASH** il gioco si chiude o si blocca.

## Script e stato
- Registrazione: `content/<dir>/<nome>.gs.lua` con `updateScript`, `handleEventScript`, `guiUpdateScript`,
  `guiHandleEventScript` (`fileName = "capocantiere.script@fn"`).
- I Lua state degli script vengono ricreati spesso: i dati persistenti vanno in `state:get()/set()`.
- Creare variabili globali nella mod genera un errore nel log ("Global variable in mod").
- Lato simulazione `app` non e' utilizzabile; `io`, `dofile`, `loadfile` assenti ovunque; `load` esiste.
- `app.loadUserdata` tiene in cache il contenuto per nome file per tutto il processo: **mai riusare un nome file**.
- GUI → simulazione: `api.cmd.makeScriptingSendEventCmd(src, id, name, param)`; nel lato sim i comandi
  sono sincroni (la callback arriva subito).

## Insidie
- **CRASH/BLOCCO**: `ipairs` su un vettore nativo (userdata) non termina mai. Usare `v:size()` / `v:at(i)`.
- **CRASH**: `edgesToRemove` con id negativi.
- **CRASH**: `NodeId.new(entita', indice)` con indice inventato passato al pathfinder. Usare solo NodeId
  forniti dal gioco (terminali delle stazioni, `inNodes`/`outNodes` dei depositi).

## Strade e fermate
- Fermata = edge object con `model = "::/stations/street/small_stops/small_old.con"` (il `.mdl` non fa nulla);
  id oggetto nel segmento tra -500000000 e -400000000 (uso -400000000).
- Sulle strade delle citta' serve rimuovere le configurazioni dei nodi (`nodeConfigsToRemove`) degli incroci,
  altrimenti assert `map_util Get`. Stesso discorso ogni volta che si aggiunge un segmento a un nodo:
  senza rigenerare le configurazioni i collegamenti tra corsie mancano e i veicoli non trovano strada.
- `small_old.con` ha bacino passeggeri **e merci** (le citta' ci scaricano merci).
- Tram: `api.engine.util.proposal.replaceSegment(e, "<template>_tram.street_template")`; le strade `xsmall`
  non hanno variante tram (allargarle collide con gli edifici). I tram non fanno inversione.

## Depositi
- Nodo libero di collegamento in coordinate locali: deposito stradale (0, -35.0), tram (-1.65, -37.42).
  Asse X locale = (dy, -dx), asse Y = (dx, dy), con (dx, dy) direzione verso l'esterno.
- Ricetta: costruzione da sola con il nodo libero a 8 m dal capolinea (`ignoreErrors=true` solo se gli
  ostacoli sono pezzi di strada), poi segmento capolinea → nodo libero. Collegarsi al nodo "congelato"
  della costruzione non e' consentito.
- Senza capolinea vicini: diramazione perpendicolare di 30 m da una strada.
- Il deposito tram ha uscite solo tram: per i binari dal deposito alle fermate si usa un Dijkstra sul
  grafo stradale (entita' nodo/segmento), non il pathfinder in modalita' bus.

## Linee e veicoli
- Linea: `api.type.Line.new()`, fermate `Line.Stop` (stationGroup, station=0, terminal=0), `makeLineCreateCmd`.
- Acquisto: `ug_require("/gui/line_vehicle_mgmt/vehicle_util.tl").makePart(modelId, true, nil)`,
  `purchaseTime` = tempo di gioco, `autoLoadConfig` tutto true, `vehicleGroups = {1}`; poi `makeVehicleSetLineCmd`.
  Se l'assegnazione fallisce di solito il deposito non raggiunge la linea.
- Verifica percorsi: `api.engine.util.pathfinding.findPathNodeToNode({a}, {b}, {modi})`.
- Merci accettate dalle citta': `api.engine.util.town.getLandUse2CargoTypes()`.
- Il mod "Auto Line Namer" rinomina le linee nuove.

## Ferrovia
- Stazione: `::/stations/rail/modular_station/modular_station.con` con `params.modules` esplicito (solo `tracks`/`length`
  non genera binari). Slot 84xxxxx binari, 74xxxxx marciapiedi, 104xxxxx tettoie, 340xxxx edifici, 10800000 scale;
  moduli `_era_a/_b/_c` esistono per tutte le epoche.
- Binari: `SegmentAndEntity.type = 1`, template `::/infrastructure/track/<simple|standard|high_speed>/...[_catenary]`.
- Passaggio a livello: prima spezzare la strada (proposta separata), poi posare il binario sul nuovo nodo.
  Nella stessa proposta: "Costruzione non consentita". Non si puo' spezzare a pochi metri da un nodo: usare il nodo.
- Deposito ferroviario: parametri `trackType` (1 simple, 2 standard, 3 high_speed) e `catenary` (1 No, 2 Si'): indici da 1.
- Locomotiva: `engineTransportModes` non vuoto e capacita' 0; elettrica se manca TRAIN tra i modi. Le motrici
  dei treni bloccati (`*_front`) hanno capacita' 0 ma non vanno usate con carrozze normali.

## Epoche
- I veicoli hanno `yearTo = 0` dopo il 2020-2030: nel 2300 restano disponibili gli ultimi modelli.
- Strade "new" (citta' moderne): solo variante `_tram_electrified`; strade "old": `_tram` e `_tram_electrified`.
- Deposito tram: parametro `tramCatenary` (1 No, 2 Si'). `ce.params` va assegnato in un colpo solo: il gioco copia la
  tabella, modifiche successive (`ce.params.x = ...`) vanno perse.
- Modalita' pathfinder: `TransportMode.ELECTRIC_TRAM` / `ELECTRIC_TRAIN` per i veicoli elettrici.
- Le azioni lunghe (ferrovie) possono superare i 60 s: timeout della mod 300 s.

## Ponti e gallerie
- Segmento ponte: `comp.type = 1`, `comp.typeIndex = api.res.bridgeTypeRep.find("::/infrastructure/bridge/steel.bridge")`
  (tipi: stone 48 m di campata, steel 90, concrete 84, tarch 240, suspension 342, trestle 28).
- Galleria: `comp.type = 2`, `typeIndex = api.res.tunnelTypeRep.find("::/infrastructure/tunnel/tunnel_a.tunnel")` (a/b/c).
- Livello dell'acqua circa 0 m (fondali negativi). I piloni nel lago danno una collisione non critica con
  un'entita' senza componenti: si puo' costruire con `ignoreErrors` solo se non ci sono edifici/strade tra le collisioni.
- Pausa del gioco: `api.cmd.makeGameSetSpeedCmd(0)`; velocita' normale `makeGameSetSpeedCmd(1)`.

## Tracciati ferroviari: cosa il gioco rifiuta
- Passaggio a livello con angolo piccolo: rifiutato gia' a 31 gradi ("Costruzione non consentita"). Sotto 45 gradi
  meglio un sovrappasso (ponte, strada + 8,5 m).
- Passaggio a livello su un incrocio stradale (nodo con 3+ segmenti) o a meno di ~12 m da esso: rifiutato.
- Strada molto piu' alta o bassa del binario: il passaggio a livello forzerebbe pendenze impossibili; meglio
  sottopasso (galleria, strada - 10 m) o sovrappasso.
- Curva troppo stretta: "Curvatura eccessiva".
- Ostacoli: industrie, campi (`FIELD`) ed edifici delle citta' (costruzioni `::/buildings/...`) danno "Collisione";
  si possono cercare prima con `octree.findEntitiesInCircle(pos, r, CONSTRUCTION/FIELD/TOWN_BUILDING)`.
- Togliere binari: `edgesToRemove` + `nodesToRemove` per i nodi che resterebbero senza segmenti (altrimenti eccezione).
- Valutare una proposta senza costruire: `api.engine.util.proposal.makeProposalData(proposal, nil).errorState`.
- Binario unico senza incroci: con 2 treni si bloccano a vicenda.
- Vendere un veicolo: `api.cmd.makeVehicleSellCmd({ veicolo }, giocatore)`.

## Parametri delle costruzioni (importante)
- I valori dei parametri sono **indici a partire da 1**: `catenary = 2` = Si', `tramCatenary = 2` = Si',
  `trackType = 1/2/3` = simple/standard/high_speed nel deposito ferroviario. Con 0/1 il gioco usa il primo valore (No).
- `ce.params` va assegnato tutto insieme (il gioco copia la tabella).

## Stazioni a 2 binari e scambi
- Moduli: marciapiede colonna 0, binari colonne 1 e 2, marciapiede colonna 3 (slot `7400000 + col*1000 + o`,
  `8400000 + col*1000 + o`); 2 terminal, binari a 5 m.
- Scambio: un binario prosegue dritto, l'altro lo raggiunge con una curva a S (80 m con "simple", 160 m con
  binari moderni, altrimenti "Curvatura eccessiva"). Il nodo dello scambio va cercato per posizione.
- Aggiungendo segmenti a un nodo che ne ha gia' (scambio, passaggio a livello): `nodeConfigsToRemove`.
- Con binari moderni niente cambi di pendenza su scambi e passaggi a livello: primo/ultimo tratto e i tratti
  ai lati del passaggio a livello in piano.
- Fermate di linea: `Line.Stop.alternativeTerminals = { StationTerminal(station=0, terminal=1) }` per usare
  qualunque binario libero.
- Alta velocita': rifiutata quasi sempre per le curve ("Curvatura eccessiva"): si usa lo standard con catenaria.

## Attenzione: eccezioni del gioco
- Alcune proposte fanno lanciare al gioco "Unknown exception" (es. `replaceSegment` su un segmento congelato di una
  costruzione). Anche se l'eccezione viene intercettata, nel mondo puo' restare un segmento senza
  `TransportNetwork` che fa crashare la partita appena la simulazione riparte. Mai modificare parti congelate.
- Veicoli: per bus/tram/carrozze scegliere solo modelli con posti passeggeri (nel 2300 il tram piu' recente,
  `f_tram_univ`, e' merci).
- Le azioni nei file vanno numerate in sequenza (lastActionId + 1): un id saltato blocca le successive.

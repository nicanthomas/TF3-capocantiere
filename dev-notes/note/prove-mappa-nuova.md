# Prove su mappa nuova (07.10.2026, anno 2020, modalita' creativa)

Mappa appena creata: 11 citta', 19 industrie, nessuna infrastruttura del giocatore. Mod v13 + bozza via sim_eval.

## Prima serie (azione 1): riuscita
- p1 ricognizione, p16 mappa, s11 tempo: ok (gameTime parte da 1000 ms).
- p2 bus tra Sarnano e Alloro (3,8 km): fermate nuove, deposito, 2 bus; collaudo ok.
- p5 ferrovia passeggeri v2 Sarnano-Alloro: stazioni a 350 e 500 m dal centro, binario di 3,2 km (8 ponti,
  28 gallerie, sovrappassi), 2 treni, navette bus in tutte e due le citta'; collaudo ok.
- p4 treno merci: fallito con la piattaforma petrolifera (industria in acqua: nessun posto per lo scalo). Le prove ora
  scartano le industrie con acqua entro 150 m.

## Seconda serie (azione 3): CRASH del gioco
Lanciate insieme p4, p14, p12, p3+p8, p19, p20, p21. Dal registro del gioco (`crash_dump/stdout.txt`):
1. "Duplicate edge detected" in `construction_util_connector` durante le verifiche a secco delle stazioni (non fatale).
2. Fatale (il gioco continua ma lo stato e' corrotto): `TransportNetworkSystem::EntityToBeRemoved: AreAllNodesEmpty`
   subito dopo una proposta rifiutata ("Costruzione non consentita") che collegava un segmento a nodi esistenti:
   si sta togliendo un'entita' che ha ancora nodi di rete occupati (pulizia dopo un fallimento).
3. Poi `GetComponentDataIndex: it != components.end()` e `NodeList::Remove` (entita' gia' tolte).
4. Crash finale: "Duplicate edges found" sull'entita' 87730 durante il posizionamento di un porto ("Posiziona sulla
   costa", quota -6 m).

Lezioni:
- Le PULIZIE (togliere costruzioni/binari appena fatti dopo un fallimento) sono la parte piu' pericolosa: togliere
  qualcosa che e' gia' collegato alla rete o ha veicoli dentro corrompe lo stato. Vanno rese prudenti: togliere solo
  costruzioni isolate, mai nello stesso momento in cui si vendono veicoli (vedi crash dell'hangar), meglio lasciare un
  pezzo inutile che rischiare il crash.
- Una prova per volta: con 7 prove nello stesso file non si capisce quale ha causato il problema.
- Porti: verificare a secco anche la rete d'acqua; evitare punti vicini ad altre costruzioni sull'acqua.

## Terza serie (mappa salvata da Nicolo', una prova per volta)
- p2 bus Abriola-Afforte: ok. p5 ferrovia Abriola-Afforte (3,1 km, 13 ponti, 20 gallerie, 2 treni, navette): ok.
- p4 treno merci (Centauro, fattoria -> allevamento, cereali): CRASH appena costruito lo scalo merci.
  Registro: "Duplicate edge detected" nella rete della costruzione (`construction_util_connector`) e poi
  `CheckDuplicateEdges` fatale, sempre con tratti di tipo 1 a quota -6 m (sotto i marciapiedi) in ogni tentativo di
  scalo. CAUSA: la stazione merci fatta solo di marciapiedi merci e binari, senza edificio, non e' valida.
  Era la stessa causa anche nei crash precedenti (il porto era solo l'ultima azione prima del crash).
- Correzione: gli scali merci ferroviari sono bloccati (errore chiaro) finche' non si copia lo schema da uno scalo
  costruito a mano (sonda s6 -> CC.CARGO_STATION_TEMPLATE) o non si prova una disposizione valida (CC.CARGO_MODULES_OK).

## Quarta serie e scoperta sui file azioni rimasti
- Dopo il crash della terza serie e la ricarica, un secondo crash identico (scalo merci vicino alla fattoria di
  Centauro) sembrava inspiegabile: nessuna prova costruiva li'. CAUSA: i file `actions_<id>_*.lua` scritti prima del
  crash e non ancora eseguiti restano nella cartella; ricaricando il salvataggio `lastActionId` torna indietro e la mod
  esegue quei file vecchi (qui p14, rete merci, con il codice vecchio non bloccato). Il gioco da solo, lasciato
  andare per 3 mesi senza azioni, non va in crash.
- Regola: dopo una ricarica, prima di mandare azioni, spostare in `vecchi` i file azioni rimasti (il middleware lo fa
  gia' all'avvio) o usare id che non si sovrappongono.
- Anello ferroviario (p12) tra Calliano, Stern e Lissone: 3 stazioni da 200 m e 19,6 km di binario costruiti, ma
  nessun deposito (l'anello non ha estremi liberi). Aggiunto il deposito su una diramazione corta
  (`CC.railDepotByBranch`, usato anche da `build_depot`). DA PROVARE.
- p4 con gli scali bloccati: errore chiaro, nessuna costruzione, nessun crash.
- p19 elicotteri Afforte-Abriola: eliporto + piazzola, elicottero H225, collaudo ok.

## Quinta serie (stessa partita, nessun crash)
- p10 deposito bus: ok. p20 linea aerea Serrano-Abriola (12 km) con campi d'aviazione e Superjet (aereo piccolo, modo
  11): costruita, ma l'aereo non si assegnava. Sonde s18/s19: tra i terminali il percorso c'e'; l'hangar del campo di
  Serrano non ha uscita verso le piste, quello di Abriola si'. Comprato l'aereo nell'hangar di Abriola (p22):
  assegnato, in volo, collaudo ok. Correzione: si sceglie un deposito/hangar che raggiunge davvero le fermate.
- p12 anello ripetuto: deposito di nuovo rifiutato, anche sulla diramazione ("Costruzione non consentita" per i primi
  raccordi). Ora il registro riporta il motivo esatto del gioco (`CC.errText`). Da riprovare.
- Stato dei veicoli nel collaudo: l'enum ha i nomi dentro `__index`; ora il collaudo scrive EN_ROUTE ecc.

## Sesta serie: anello completato
- Deposito sull'anello: sugli estremi liberi il deposito urtava il binario accanto o una strada di campagna. Aggiunti
  `CC.leadTrack` (binario d'accesso spostato di lato) e `CC.depotAtEndSafe` (prova diretta, poi binario d'accesso solo
  dove l'area del deposito e' libera) e la ricerca su tutte le stazioni. Risultato: deposito costruito a Calliano.
- p25: linee nei due sensi sulle 3 stazioni dell'anello (create_line_from_stations, pattern ring): 2 linee, 1 treno
  ciascuna, collaudo ok.

## Settima serie: confini della mappa e scalo merci (causa vera)
- Confini (sonde s20, s21): `terrain.getBoundingBox()` da' un Box2 {min, max} (qui -8192..8192), `isValidCoordinate`
  e' false fuori, e oltre il bordo `getHeightAt` ripete l'ultimo valore (quindi le altezze non bastano a capirlo).
  Aggiunti `CC.mapBox` e `CC.inMap(x, y, margine)`: scartano i posti fuori mappa per stazioni, aeroporti, porti
  (la ricerca della costa si ferma al bordo), binari d'accesso, diramazioni e controlli d'area.
- p23 (scalo merci con edificio e scale): CRASH identico ("Duplicate edges found" a quota -5,4 m, tratti di 2,5 m
  di traverso sotto i marciapiedi). Quindi l'edificio non c'entrava.
- Ricarica: il salvataggio "partita vuota di test" e' quello iniziale (1 gen 2020, lastActionId 0): tutte le prove
  precedenti sono sparite. Un file azioni "neutro" con un `sim_result` di una chiave inesistente blocca la mod per 300 s
  (attende il lato simulazione): i file neutri devono avere `actions = {}`.
- Costruiti A MANO 3 scali merci (terminal stazione merci, 1 binario, 160 m) e copiati con la sonda s22. CAUSA VERA:
  il marciapiede merci usa gli slot 64xxxxx ed e' largo DUE colonne (binario nella colonna 2: 84020xx); la mod lo
  metteva come un marciapiede passeggeri (74xxxxx, binario nella colonna 1) e il binario finiva sopra il marciapiede.
  Schema: `3701980` main_building_1_cargo, `64000xx` platform_cargo_era_c, `84020xx` binario, xx = -10..20,
  parametri `tracks = 1`, `length = 3`, `specialization = 1`.
- Ora gli scali merci usano solo questo schema (1 binario, 160 m, treni merci entro 150 m, un treno per linea semplice;
  piu' treni con la rete merci e i binari d'attesa). `CC.buyCargoTrain` mancava: aggiunto.

## 08.10.2026 sera (build 40420, scambio file in mod_presets con prefisso capocantiere_)
- Studio della partita di terzi completato: `dev-notes/schemi_terzi/`.
- partita vuota di test, id 1: **p23 scalo merci OK** (Raffineria di petrolio di Maretto, costruzione 89548, gruppo 89601,
  2 estremi, posto a R 180 m / 60 gradi dopo 2 posti rifiutati). Nessun crash.
- id 24-54 (notte): anello a doppio binario p35, molte prove. Binario 2 parallelo: strade di campagna spezzate nella
  STESSA proposta (uno splitStreet separato prima era rifiutato, "Costruzione non consentita"); estremi della stazione
  d'arrivo scambiati quando il lato non corrisponde. Il binario 1 (5-6 km, molti ponti) riesce solo con alcuni estremi;
  il parallelo urta altre strade. Non finito.

## 09.10.2026 mattina
- id 57-58, s35: stazioni integrate delle industrie (camion per tutte le industrie a terra; navi + eliporto per
  piattaforme petrolifere; navi per aree di pesca; nessuna ferroviaria).
- id 59-60, **p37 OK**: argilla in camion Cava -> Mattonificio di Castelgrande con le stazioni integrate (linea 89641,
  deposito costruito, 2 camion, collaudo ok).
- id 61-67, **p4 OK** dopo due correzioni (`CC.cargoFor` mancante; scalo cercato vicino alla stazione integrata):
  cereali in treno Azienda agricola di Centauro -> Allevamento di Abriola, 5944 m, linea 90082, collaudo ok.
- id 68-80, **p14 OK** (argilla, Cava -> Mattonificio di Castelgrande, linea 89873, collaudo ok): binario d'attesa
  alla stazione 1 impossibile (400 m dritti rifiutati) -> ora si prova 400/250/160 m, poi si va avanti con un treno.
- id 81-88, segnali: **p39/p38 OK** dopo la correzione dell'id provvisorio dell'oggetto (-400000000 - indice 0-based);
  5 segnali a doppio senso ogni 400 m sulla linea di p14.
- id 89-107: porto (p21, p40-p43): rifiutato senza messaggi con i moduli copiati; vedi STATO punto 3.
- id 108-113: **p2 OK** (bus Afforte-Abriola, linea 89994), **p3 OK**, **p8 OK** dopo la correzione di `extend_line`
  (linea allungata a Stern, 3 fermate).
- id 114-121: gioco fatto correre (velocita' 4 da `lua_eval`), s23/s36 (dati della flotta), **p44 OK**:
  `adjust_line_fleet` propone +3 bus sulla linea 89994 (giro 1105 s), camion e treno adeguati; applicato con intervallo
  200 s: 4 bus comprati.
- v14 dev (`v14-bozza-32c86032`) installata nella cartella della mod (attiva al prossimo caricamento).

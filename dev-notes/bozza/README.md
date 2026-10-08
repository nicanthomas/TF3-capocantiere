# Bozza delle funzioni nuove (NON ANCORA PROVATE IN GIOCO)

Codice scritto senza il gioco: va provato in gioco con `sim_eval` (DEV_MODE) sulla partita di test, corretto e solo
dopo unito alla mod con `python dev-notes/build_script.py --bozza`. Le parti dell'API usate sono quelle gia' verificate,
tranne dove indicato.

| File | Contenuto | Rischio |
|---|---|---|
| `b1_base.lua` | Registro delle entita' create da ogni azione (per *annulla*), verifica a secco delle proposte (`CC.buildCmd`), controllo argomenti, funzioni su linee/veicoli/depositi, bacino delle stazioni (`catchmentAreaSystem.getStationCatchables`, preso dallo script ufficiale delle notifiche) | basso |
| `b2_rete.lua` | Bus tra citta', navetta stazione-centro, aggiungi/togli/sostituisci veicoli (`makeVehicleReplaceCmd`, come lo script ufficiale delle missioni), cancella linea (`makeLineDestroyCmd`), allunga linea (`makeLineUpdateCmd`, effetto da verificare), annulla | medio |
| `b3_ferrovia.lua` | Posizionamento delle stazioni per bacino, collegamento tra stazioni (codice di `build_rail_line` reso riusabile), treni merci con scali merci, ferrovia passeggeri v2 con navette | medio (nomi dei moduli merci da verificare con la sonda s3/s6) |
| `b4_template.lua` | Aerei, elicotteri, navi (costruzioni copiate da quelle fatte a mano: sonda s6 -> `CC.TEMPLATES`), strada d'accesso automatica, superstrade (incroci tutti a livelli separati) | alto: schemi da ricavare in gioco |
| `b5_stazioni.lua` | Dimensionamento delle stazioni (`CC.planStation`: lunghezza dai treni, binari da linee/treni, transito, scali per merce), stazioni con N binari e lunghezza variabile (`CC.buildRailStationN`), ripieghi in caso di conflitto di spazio (`CC.placeStationSmart`, mai demolizioni), treni mai piu' lunghi del marciapiede, `build_depot` | alto: parametro "length", posizioni dei moduli, lunghezza dei modelli (sonda s10) |
| `b6_binari.lua` | Diramazioni, doppio binario con segnali a senso unico (`CC.linkStationsDouble`), binari d'incrocio/attesa (`CC.buildPassingLoop`), segnali (`CC.addSignals`), anello nei due sensi (`build_rail_ring`) | alto: come si piazza un segnale da script (sonda s8) |
| `b7_linee.lua` | Ordine delle fermate (avanti e indietro, anello e verso opposto), `create_line_from_stations`, merci a piu' fermate con ritorno e vagoni misti (`build_cargo_rail_network`), raccordo su un binario esistente (`CC.branchFromTrack`) e `build_rail_station` (traffico misto) | medio-alto: divisione di un binario esistente |
| `b8_collaudo.lua` | Collaudo (`CC.checkLine`, `check_line`, `check_network`: percorsi, veicoli fermi, deposito, bacino, statistiche), `read_map` per pianificare | medio: stato/posizione dei veicoli e statistiche (sonda s9) |
| `b9_avvolgi.lua` | Avvolge tutte le azioni: controllo degli argomenti anche per le azioni vecchie, registro -> `result.created`, pulizia dopo i fallimenti delle azioni su strada, collaudo subito dopo la costruzione (`result.collaudo`), avviso pausa | basso |

`cc_lib.lua` ha ricevuto una sola modifica compatibile: `buildCurvedTrack` legge `CC.CURVE_SEG_TYPE` e
`CC.CURVE_ROAD_TYPE` (se non impostati: binario, come prima). Serve alle superstrade.

## Test senza gioco

`python3 dev-notes/bozza/run_mock.py`: 64 controlli con un finto `api` (registro, annidamento, annulla, pulizia, verifica
a secco, argomenti, copia della composizione dei veicoli, piano delle stazioni, disposizione dei binari, ordine delle
fermate, giro dell'anello, collaudo con veicolo fermo/in movimento). Non sostituisce le prove in gioco.

## Prove in gioco (stasera)

Ordine e comandi in `dev-notes/note/piano-stasera.md`. Sonde in `dev-notes/sonde/` (sola lettura), prove in `dev-notes/prove/`
(costruiscono: farle sulla partita di test, salvata prima).

## Dopo le prove

1. Correggere la bozza.
2. Riempire `CC.TEMPLATES`, `CC.CARGO_STATION_TEMPLATE`, `CC.VEHICLE_FOLDERS` con i dati delle sonde.
3. `python dev-notes/build_script.py --bozza` (v14: bozza + velocita' del gioco, versione della mod, tempo di gioco e build
   in state.lua + esportazione di state.lua piu' rada se e' lenta + inoltro automatico delle azioni nuove al lato
   simulazione + comando `set_speed`).
4. Middleware con `CAPOCANTIERE_BOZZA=1` per dare a Claude i tool nuovi (`middleware/tools_bozza.py`).
5. Quando un'azione e' affidabile: spostarla da `bozza/` a `cc_actions.lua` e il suo schema in `tools.py`.

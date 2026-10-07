# Bozza delle funzioni nuove (NON ANCORA PROVATE IN GIOCO)

Codice scritto senza il gioco: va provato in gioco con `sim_eval` (DEV_MODE) sulla partita di test, corretto e solo
dopo unito alla mod con `python dev/build_script.py --bozza`. Le parti dell'API usate sono quelle gia' verificate,
tranne dove indicato.

| File | Contenuto | Rischio |
|---|---|---|
| `b1_base.lua` | Registro delle entita' create da ogni azione (per *annulla*), verifica a secco delle proposte (`CC.buildCmd`), controllo argomenti, funzioni su linee/veicoli/depositi, bacino delle stazioni (`catchmentAreaSystem.getStationCatchables`, preso dallo script ufficiale delle notifiche) | basso |
| `b2_rete.lua` | Bus tra citta', navetta stazione-centro, aggiungi/togli/sostituisci veicoli (`makeVehicleReplaceCmd`, come lo script ufficiale delle missioni), cancella linea (`makeLineDestroyCmd`), allunga linea (`makeLineUpdateCmd`, effetto da verificare), annulla | medio |
| `b3_ferrovia.lua` | Posizionamento delle stazioni per bacino, collegamento tra stazioni (codice di `build_rail_line` reso riusabile), treni merci con scali merci, ferrovia passeggeri v2 con navette | medio (nomi dei moduli merci da verificare con la sonda s3/s6) |
| `b4_template.lua` | Aerei, elicotteri, navi (costruzioni copiate da quelle fatte a mano: sonda s6 -> `CC.TEMPLATES`), strada d'accesso automatica, superstrade (incroci tutti a livelli separati) | alto: schemi da ricavare in gioco |
| `b9_avvolgi.lua` | Avvolge tutte le azioni: registro -> `result.created`, pulizia dopo i fallimenti delle azioni su strada, avviso pausa | basso |

`cc_lib.lua` ha ricevuto una sola modifica compatibile: `buildCurvedTrack` legge `CC.CURVE_SEG_TYPE` e
`CC.CURVE_ROAD_TYPE` (se non impostati: binario, come prima). Serve alle superstrade.

## Test senza gioco

`python3 dev/bozza/run_mock.py`: 28 controlli con un finto `api` (registro, annidamento, annulla, pulizia, verifica
a secco, argomenti, copia della composizione dei veicoli). Non sostituisce le prove in gioco.

## Prove in gioco (stasera)

Ordine e comandi in `docs/piano-stasera.md`. Sonde in `dev/sonde/` (sola lettura), prove in `dev/prove/`
(costruiscono: farle sulla partita di test, salvata prima).

## Dopo le prove

1. Correggere la bozza.
2. Riempire `CC.TEMPLATES`, `CC.CARGO_STATION_TEMPLATE`, `CC.VEHICLE_FOLDERS` con i dati delle sonde.
3. `python dev/build_script.py --bozza` (v14: bozza + velocita' del gioco in state.lua + inoltro automatico delle
   azioni nuove al lato simulazione + comando `set_speed`).
4. Middleware con `CAPOCANTIERE_BOZZA=1` per dare a Claude i tool nuovi (`middleware/tools_bozza.py`).
5. Quando un'azione e' affidabile: spostarla da `bozza/` a `cc_actions.lua` e il suo schema in `tools.py`.

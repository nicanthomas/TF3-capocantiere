# Schemi copiati dal salvataggio di terzi (08.10.2026, build 40420)

Partita "My 1st Sandbox with mods Final" (anno 2082, mappa -7168..7168, 16 citta', 46 industrie, 243 stazioni,
95 linee, 166 depositi). Accesso UNA SOLA VOLTA: qui c'e' tutto quello che e' stato letto (JSON compatto, sola lettura).

| File | Sonda | Contenuto |
|---|---|---|
| s24.json | s24_copia_schemi | schemi (moduli+parametri+transf) per tipo: scali merci (8 disposizioni), stazioni passeggeri, porti modulari, magazzini, depositi/officine strada/tram/treno/nave, anti-inquinamento, fermate modulari (anche merci), aeroporti, eliporti, stazione sotterranea (mod); catalogo dei moduli |
| s25.json | s25_stazioni_industrie | 32 industrie con la loro stazione INTEGRATA (station, group, terminali, costruzione dell'industria, non del giocatore) |
| s26.json | s26_binari_segnali | tipi di binario/strada, ponti/gallerie per typeIndex, distanze tra binari paralleli (5.0 m: 43 casi) |
| s27.json | s27_linee_veicoli | 95 linee con composizioni dei veicoli, modelli usati, impostazioni delle fermate |
| s28..s32 | s28..s32 | ricerca dei SEGNALI (vedi sotto) |
| s29.json | s29_stazione_grande | stazione passeggeri da 8 binari (282 moduli completi) + parametri di tutte le modular_station |
| s8.json | s8_segnali | errore (pairs su api.type.ComponentType non da' piu' i nomi nella 40420) |

## Risultati principali
- **Scali merci** (`RS/modular_station.con`, slot 34000xx edifici, 63999xx/64000xx/64029xx marciapiedi merci, 84019xx-84020xx binari):
  disposizioni con tracks 1/3/4, length 3/5, specialization 1 (merci); marciapiedi `platform_cargo_era_a/b/c`,
  `_c_bulk/_flatbed/_goods/_liquid`; edifici `main_building_1/2/3_cargo`, `side_building_1_cargo`.
  Esempio completo a 1 binario: s24 `rail_cargo[0]` (Bergen Station East).
- **Stazioni passeggeri**: 1 binario/length 1 (7 moduli) e 8 binari/length 5 (s29: 64 `platform_passenger_era_c`,
  64 `platform_passenger_roof_era_c`, 64 `addon_platform_passenger_stairs_era_c`, 80 binari, edifici era_b).
  Nessuna stazione ferroviaria sotterranea o sopraelevata nella partita (tutte a raso). Nessun modulo di comfort.
- **Fermate stradali modulari** `modular_terminal.con`: marciapiedi merci `cargo_platform[_bulk|_flatbed|_goods|_liquid]`,
  parametri `platforms`, `specialization`, `tramTrack` (fermata merci per camion/tram).
- **Porti** `harbor_modular.con`: moli `small_pier/medium_pier`, banchine `passenger_dock_25_25/50_12/100_25/100_50`,
  `pedestrian_entrance`; parametro `smallterminals`.
- **Magazzini** `warehouses/warehouse.con` con modulo `wh_universal.module` (slot 632502500).
- **Stazione sotterranea** `stations/street/underground_station/underground_station.con` (mod di terzi; params
  platformLength, platformOrientation, tramCatenary).
- **Industrie**: ogni industria ha una stazione propria (`near[].station`, `terminals`, non del giocatore): base per
  il punto 1b di STATO.
- **SEGNALI** (s30-s32): 210 segnali ferroviari, tutti `::/infrastructure/signal/signal_path_c.mdl` (203) o
  `signal_path_a.mdl` (7), `SIGNAL_LIST.signals[1].type = 0`, nessun segnale a senso unico ne' a blocco.
  - Sul binario: `BASE_EDGE.objects` e' una TABELLA Lua `{ {entita', tipo} }`; tipo 2 = segnale, 0/1 = fermate stradali.
  - Entita' del segnale: `EDGE_OBJECT` (CT 88, campo `param` = posizione 0..1 lungo il binario), `SIGNAL_LIST` (CT 26:
    `signals[1]` con `type`, `state`, `stateTime`, `edgePr = { EdgeId, bool }`), `MODEL_INSTANCE_LIST` (CT 57:
    `fatInstances[1].modelId`, `transf`).
  - **Verso**: `edgePr[2] = true` -> il segnale guarda nel verso node0 -> node1 (rotazione del modello = tangente del
    binario); `false` -> verso opposto. Il modello sta ~0.5 m di lato e +0.55 m sopra l'asse del binario.
  - Un solo segnale per binario; doppio binario a 5.0 m di interasse.

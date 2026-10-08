# STATO DEL PROGETTO — leggere per primo (aggiornato 08.10.2026)

Questo file permette a una chat nuova di ripartire senza rileggere le conversazioni precedenti.
Dettagli: `docs/prove-mappa-nuova.md` (cronologia prove), `docs/studio-salvataggio-terzi.md` e `docs/scoperte-api.md`
(API verificate), `dev/bozza/README.md` (cosa c'e' in ogni file della bozza).

## 1. Regole di Nicolo' (vincolanti)
- Rispondere in italiano, al massimo una domanda per volta, lavorare in autonomia. Non inventare l'API: provarla.
- Sul PC scrivere SOLO nella cartella `mods` e in `capocantiere` (dati utente). Backup prima di modificare un file
  esistente. Non cancellare nulla. Chiedere prima di toccare altre cartelle.
- Chiave API: mai usarla ne' ripeterla (Nicolo' ha impostato ANTHROPIC_API_KEY da solo).
- GitHub: push SOLO via Composio (`GITHUB_COMMIT_MULTIPLE_FILES`, owner `nicanthomas`, repo `TF3-capocantiere`,
  branch `main`); titolo commit `gg.mm.aaaa-NR-Descrizione`; verificare gli SHA dei blob dopo il push.
- Partita: modalita' creativa, anno >= 2020. Tutto quello che si piazza deve FUNZIONARE (anche i depositi).
  Restare dentro i confini della mappa.
- Crash: la partita e' salvata; chiudere il gioco, riaprirlo e ricaricare da soli (sequenza al punto 4).
- RISPARMIO CREDITI (richiesta 08.10.2026): poche chiamate, piu' prove senza rischio nello stesso file azioni, le
  prove rischiose da sole; screenshot solo se serve (crash); se un servizio non risponde fermarsi e scriverlo invece
  di aspettare; non rileggere file grandi interi.

## 2. Architettura
- Mod Lua `mod/tfcapocantiere_1` (versione installata nel gioco: v13) + middleware Python `middleware/` (Claude).
- Bozza delle funzioni nuove in `dev/bozza/b1..b9` (provata in gioco con `sim_eval`, DEV_MODE). Diventera' v14 con
  `python dev/build_script.py --bozza` (prima fare il backup della v13 nella cartella mods).
- Protocollo: la mod esegue `actions_<id>_<nonce>.lua` con id = lastActionId+1 (stato GUI, salvato nella partita;
  si legge in `state.lua`), scrive `results_<id>_<nonce>.lua` e cancella il file azioni.
  `sim_eval` mette in coda il codice nel lato simulazione: il valore si legge con un `sim_result` (chiave `g<id>_<n>`)
  nell'azione successiva. Un `sim_result` di una chiave che non esiste blocca la mod 300 s: i file "neutri" devono
  avere `actions = {}`.
- Dopo una ricarica lastActionId torna al valore del salvataggio: i file azioni rimasti con id futuri verrebbero
  eseguiti. Neutralizzarli (stesso nome, `actions = {}`) prima di proseguire.

## 3. Ciclo di prova (dalla chat cloud)
1. `python3 dev/strumenti/step.py ID "chiavi_da_leggere" prove/pX.lua[,sonde/sY.lua] [gruppo2 ...]`
   -> scrive `/mnt/user-data/outputs/cc/actions_ID_<nonce>.lua` (bozza + prove, ogni prova in pcall).
2. SendUserFile del file, poi `device_commit_files` in
   `C:\Program Files (x86)\Steam\userdata\888286537\3493540\local\capocantiere\` (stesso nome).
3. Attendere ~5 s, `device_stage_files` di `results_ID_<nonce>.lua`, poi
   `python3 dev/strumenti/show.py <file staged> [lunghezza]`.
4. Il risultato di una `sim_eval` arriva con l'azione ID+1 che contiene la chiave `gID_0`.
   Per risparmiare: mettere nell'azione ID+1 anche la prova successiva (se non rischiosa).
- Il bridge non ha `device_bash`: niente `ls` sul PC; `device_list_dir` della cartella e' enorme (evitarlo).
- Log del crash: `...\3493540\local\crash_dump\stdout.txt` (stage + grep "Duplicate|Assertion").

## 4. Ripresa dopo un crash (clic, schermo 1568x656 circa)
Exit sul dialogo (950,392) -> eventuale "Uscire dal gioco?" di Steam (779,340) -> Gioca (171,196) ->
Carica partita (540,560) -> "partita vuota di test" Carica (360,293) -> Avvia partita (1487,595).
Velocita': pausa (1404,648), massima (1456,648). Il salvataggio "partita vuota di test" e' quello INIZIALE
(1 gen 2020, lastActionId 0, mappa vuota): ogni ricarica cancella le prove fatte.

## 5. Stato del gioco al 08.10.2026
- Partita "partita vuota di test" caricata dopo il crash del 07.10 sera, lastActionId = 7 (prossimo id: 8).
- Sulla mappa ci sono solo 3 scali merci costruiti A MANO (id 89222, 89437, 89493, 1 binario, 160 m).
- Nella cartella restano file azioni neutri per gli id 4 e 33 e due vecchi (241, 242): innocui.

## 6. Cosa funziona (provato in gioco)
| Funzione | Prova | Note |
|---|---|---|
| Bus tra citta' (fermate, deposito, bus) | p2 | collaudo ok |
| Ferrovia passeggeri v2 (stazioni, binario con ponti/gallerie, treni, navette bus) | p5 | collaudo ok |
| Deposito bus su richiesta | p10 | |
| Elicotteri (eliporto + piazzola, H225) | p19 | collaudo ok |
| Linea aerea con campi d'aviazione (aereo piccolo, modo 11) | p20+p22 | si sceglie l'hangar che raggiunge le piste |
| Anello ferroviario 3 stazioni + deposito con binario d'accesso + linee nei due sensi | p12, p24, p25 | |
| Collaudo linee (percorsi, veicoli, deposito, bacino) | p15/s14 | 93/94 sulla rete di terzi |
| Annulla a fasi (veicoli -> binari -> costruzioni) | mock + middleware | evita il crash dell'hangar |
| Confini mappa `CC.mapBox` / `CC.inMap` | s20, s21 | -8192..8192 su questa mappa |

## 7. Da fare (in ordine)
1. **p23**: scalo merci con lo schema copiato (`CC.cargoStationBuilder`, slot 64xxxxx). Rischio crash: da sola.
   `python3 dev/strumenti/step.py 8 "" prove/p23_scalo_merci.lua`
2. Se tiene: p4 (treno merci industria -> industria, `build_cargo_rail_line`) e p14 (rete merci).
3. Porto (p21), deposito navale; doppio binario con segnali (p13; prima piazzare un segnale a mano e leggerlo con s8).
4. p3/p8 (aggiungi/sostituisci veicoli, allunga linea); far correre il gioco e verificare che i veicoli si muovano.
5. Build v14 (`dev/build_script.py --bozza`), backup v13, installazione in mods, prova col middleware.
6. Aggiornare questo file e `docs/prove-mappa-nuova.md` a ogni passo.

## 8. Cause di crash note (non ripetere)
- Scalo merci con marciapiedi merci negli slot passeggeri (74xxxxx): "Duplicate edges found" a quota -6 m.
  Schema giusto: `3701980` main_building_1_cargo, `64000xx` platform_cargo_era_c, `84020xx` binario,
  xx = -10..20, `tracks=1, length=3, specialization=1`. Altre misure: prima copiarle da uno scalo fatto a mano (s22).
- Togliere binari insieme alla stazione collegata, o vendere veicoli insieme al deposito, nella stessa chiamata.
- File azioni rimasti dopo una ricarica (vedi punto 2).
- Piu' prove rischiose nello stesso file: non si capisce quale ha causato il crash.

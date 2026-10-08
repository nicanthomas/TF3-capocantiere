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
- GITHUB SEMPRE AGGIORNATO (08.10.2026): dopo ogni passo concluso (prova riuscita o fallita, sonda letta,
  correzione) fare subito il commit, senza accumulare. Tenere allineati col tempo anche: `README.md` (tabella delle
  azioni con lo stato "Provato in gioco", requisiti, costo per sessione quando misurato), questo file (sezioni 5-8)
  e `docs/prove-mappa-nuova.md`. Quando la v14 e' provata: release su GitHub con lo zip di
  `python dev/build_script.py --release` (DEV_MODE spento), screenshot o GIF di una richiesta trasformata in
  costruzione nel README, costo medio di una sessione nel README. Push con la patch compressa applicata nel
  workbench di Composio (meno crediti), controllando gli SHA dei file.
- PRINCIPIO GENERALE (08.10.2026): la mod e il middleware agiscono SOLO dopo un input esplicito di Nicolo'.
  Nessuna azione automatica, programmata o in background nel gioco (niente cicli che costruiscono, comprano,
  vendono o modificano da soli). Ogni costruzione, acquisto o modifica parte da una sua richiesta e finisce li'
  (il collaudo subito dopo una costruzione fa parte della stessa richiesta e non cambia nulla).
- RISPARMIO CREDITI (richiesta 08.10.2026): poche chiamate, piu' prove senza rischio nello stesso file azioni, le
  prove rischiose da sole; screenshot solo se serve (crash); se un servizio non risponde fermarsi e scriverlo invece
  di aspettare; non rileggere file grandi interi.

## 1b. Avvio della chat: chiedere SUBITO tutte le autorizzazioni (una volta sola, all'inizio)
0. **VERIFICARE I PERCORSI (08.10.2026)**: Nicolo' ha spostato la cartella di INSTALLAZIONE del gioco fuori da C:
   (spazio finito). Tutti i percorsi di questo file (cartella `capocantiere`, `mods`, `crash_dump`) erano in
   `C:\Program Files (x86)\Steam\userdata\888286537\3493540\local\`. Di solito spostare il gioco in un'altra
   libreria Steam NON sposta `userdata` (resta nella cartella di Steam), ma va verificato:
   - controllare con `device_list_dir` se `...\local\mods\tfcapocantiere_1`, `...\local\capocantiere` e
     `...\local\crash_dump` esistono ancora; se no, cercare la nuova posizione (nuova cartella di Steam o della
     libreria) e chiedere l'accesso a quella;
   - se la cartella `mods` usata dal gioco e' cambiata, COPIARE la mod `tfcapocantiere_1` nella nuova cartella `mods`
     (prima backup; l'originale NON si cancella senza chiedere: regola "non cancellare nulla") e verificare nel
     gioco che la mod risulti attiva;
   - aggiornare in questo file e in `middleware/game_bridge.py` (DEFAULT_DIR o variabile CAPOCANTIERE_DIR) i
     percorsi nuovi, poi proseguire.
Prima di qualsiasi prova, in un unico giro, cosi' Nicolo' puo' approvare tutto e poi lasciare lavorare:
1. Controllo del computer (`request_access`): Transport Fever 3 e Steam (servono per la ripresa dopo un crash).
2. Cartella `C:\Program Files (x86)\Steam\userdata\888286537\3493540\local\capocantiere` (lettura/scrittura) e,
   se non e' gia' dentro, `...\3493540\local\crash_dump` (sola lettura del log dei crash).
3. Verificare con una chiamata leggera che il GitHub di Composio risponda (es. `GITHUB_GET_A_BRANCH` su main).
4. Clonare il repo (`git clone https://github.com/nicanthomas/TF3-capocantiere.git`, pubblico) e lanciare
   `cd dev/bozza && python3 run_mock.py` (deve dare 65 ok).
Se qualcosa manca, dirlo subito in un solo messaggio, non a meta' lavoro.

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

## 2b. Architettura "Planner + Executor" e flotta ON-DEMAND (decisione di Nicolo', 08.10.2026)
- Planner = Claude + middleware: capisce la richiesta e chiama solo strumenti di alto livello (id di citta',
  industrie, stazioni, linee; mai coordinate). Executor = mod Lua: tutta la geometria (posti, binari, curve, ponti,
  depositi) e i calcoli. GIA' cosi' (verificato: nessuno dei 29 strumenti riceve coordinate).
- NESSUN ciclo automatico in background che cambia la flotta. Comportamento voluto:
  1. CREAZIONE: quando crea una linea, la mod analizza il percorso (lunghezza/tempo di un giro, capienza dei
     veicoli, domanda) e mette il numero giusto di veicoli iniziali, poi si ferma.
  2. GESTIONE MANUALE: dopo la creazione la linea resta statica; il controllo e' al 100% del giocatore.
  3. ON-DEMAND: adeguare i veicoli o rinnovare la flotta SOLO quando Nicolo' lo chiede esplicitamente
     (es. "Adegua i veicoli della linea X"). Strumento previsto: `adjust_line_fleet(line_id, target_interval?,
     renew_old?)`: la mod calcola e applica in una volta sola (aggiunge/toglie/sostituisce) e riferisce cosa ha fatto.
- Dati necessari (DA VERIFICARE con la sonda `dev/sonde/s23_flotta.lua`, sola lettura): tempo di un giro o
  intervallo della linea, eta' e vita utile dei veicoli, capienza, passeggeri/merci in attesa alle fermate.
  NB: `api.engine.util.line.getFrequency` NON esiste; esistono getMaxFrequency, getLineCapacityUsages,
  calcLineStationThroughput. Non scrivere l'analisi su funzioni non provate.
- Per la sonda serve una linea con veicoli in movimento da qualche minuto di gioco: lanciarla dopo aver costruito
  una linea (es. bus p2) e lasciato correre il gioco. `python3 dev/strumenti/step.py ID "" sonde/s23_flotta.lua`.

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
0. **Studio COMPLETO del salvataggio di terzi (accesso UNA SOLA VOLTA, sola lettura)**. Nel primo studio (07.10)
   furono copiati solo aerei, eliporti e porto; gli scali merci e i segnali NO (e la sonda s12 contava i segnali con
   `CT.BASE_EDGE_TRACK`, che non esiste: per questo "0 segnali"). Questa volta copiare TUTTO, perche' dopo la
   partita non sara' piu' disponibile.
   - La partita la carica NICOLO' A MANO (deve disattivare ogni volta le mod "deluxe" e "preorder"). La chat
     aspetta che lo dica.
   - Dopo il caricamento: lastActionId riparte dal valore di quella partita -> leggere `state.lua` e neutralizzare
     eventuali file azioni rimasti (sezione 2) prima di mandare id nuovi.
   - Un primo file con le sonde (tutte sola lettura, ognuna in pcall): `sonde/s24_copia_schemi.lua` (tutte le
     disposizioni diverse di scali merci, stazioni passeggeri, porti, magazzini, depositi/officine, impianti
     anti-inquinamento, fermate, stazioni sotterranee/sopraelevate/metropolitana anche di mod + catalogo dei moduli), `sonde/s25_stazioni_industrie.lua` (stazioni integrate,
     un'industria per tipo), `sonde/s26_binari_segnali.lua` (tutta la mappa: tipi di binario/ponte/galleria,
     segnali con componenti e modelli, distanza del doppio binario), `sonde/s27_linee_veicoli.lua` (linee, modelli,
     impostazioni di carico/scarico delle fermate), `sonde/s8_segnali.lua`. Se il risultato e' troppo grande o
     qualcosa va storto, rimandarle separate. Opzioni: `CC.PROBE_MAX_LAYOUTS` (8), `CC.PROBE_MAX_SIGNALS` (30).
   - Guardare i risultati e, se manca qualcosa (un tipo di costruzione, un dettaglio dei segnali, un campo),
     scrivere SUBITO un'altra sonda e rilanciarla finche' la partita e' aperta. Controllare almeno: scalo merci a 2+
     binari e altre lunghezze, stazione sotterranea e sopraelevata (e metropolitana, se la sua mod e' attiva:
     `underground_station.con` e' di una mod di terzi), segnale normale e a senso unico (modello, lato, posizione sul binario), porto
     modulare, magazzino, stazione con moduli di comfort, fermata merci per tram/camion, stazione integrata.
   - Salvare i risultati NEL REPO (questa volta si', compressi o riassunti se grandi) in `dev/schemi_terzi/`, e
     riportare gli schemi utili nella bozza (CC.TEMPLATES, schemi scali, segnale). Poi la chat carica DA SOLA
     la "partita vuota di test" (nessuna mod da disattivare; clic come nella sezione 4, partendo
     dal menu principale: Esc/menu -> Esci al menu, poi Carica partita).
1. **p23**: scalo merci con lo schema copiato (`CC.cargoStationBuilder`, slot 64xxxxx). Rischio crash: da sola.
   `python3 dev/strumenti/step.py 8 "" prove/p23_scalo_merci.lua`
1a. **Anello ferroviario con binari adeguati (richiesta di Nicolo' 08.10.2026)**: l'anello provato ieri aveva un solo
    binario per i due sensi. Voluto: (A) 2 binari, uno per senso, oppure (B) 1 binario con tratti a doppio binario
    per l'incrocio dei treni. Ordine:
    1. segnale copiato dal salvataggio di terzi (punto 0, sonde s26/s8) oppure piazzato A MANO su un binario, poi sonda
       `s8_segnali.lua` (ora cerca i binari con l'octree) per copiare come si piazza da script (`CC.SIGNAL_MODEL`, `CC.addSignals` in b6 sono da verificare);
    2. opzione A: `build_rail_ring` con `double_track = true` (usa `CC.linkStationsDouble`, segnali a senso unico),
       2 linee (una per senso), piu' treni per senso; collaudo e far correre il gioco;
    3. opzione B: binario unico + `CC.buildPassingLoop` (b6) fuori dalle stazioni, con segnali agli scambi.
    Ripiego senza segnali: binario unico con stazioni a 2 binari (incrocio in stazione), valido con pochi treni.
1b. **Stazioni integrate nei siti industriali (novita' TF3)**: sonda (sola lettura) per capire se le industrie hanno
    gia' una stazione propria utilizzabile in una linea (gruppo/stazione/terminali, mezzi serviti, bacino). Se si':
    le linee merci usano quelle invece di costruire scali (meno costruzioni, meno rischio di crash).
2. Se tiene: p4 (treno merci industria -> industria, `build_cargo_rail_line`) e p14 (rete merci).
3. Porto (p21), deposito navale; doppio binario con segnali (p13; prima piazzare un segnale a mano e leggerlo con s8).
4. p3/p8 (aggiungi/sostituisci veicoli, allunga linea); far correre il gioco e verificare che i veicoli si muovano.
4b. Flotta on-demand (sezione 2b): costruire una linea bus, far correre il gioco, sonda s23; poi numero iniziale
    di veicoli calcolato alla creazione e strumento `adjust_line_fleet` (solo su richiesta, nessun ciclo automatico).
4c. Puntualita' delle consegne (novita' TF3): allargare la sonda s23 ai dati di ritardo/puntualita' e usarli in
    "adegua i veicoli della linea X" (solo su richiesta).
5. Build v14 (`dev/build_script.py --bozza`), backup v13, installazione in mods, prova col middleware.
5b. Novita' TF3 da aggiungere dopo la v14 (ognuna: prima sonda o copia di una costruzione fatta a mano):
    - potenziatori di produzione (lavoratori, fertilizzanti...): leggere quali beni potenziano quale industria;
      Claude propone e, su richiesta, costruisce la catena (e' una linea merci normale);
    - magazzini/stoccaggio vicino a porti e scali (schema `warehouses/warehouse.con`, visto nel salvataggio di terzi);
    - scelta dei veicoli anche per velocita' di carico, comfort, rumore, inquinamento (campi dei modelli da trovare);
    - tram merci e metropolitana leggera (copiare stazioni/binari fatti a mano);
    - moduli di comfort nelle stazioni passeggeri (copiare da una stazione fatta a mano);
    - barriere antirumore/alberi su richiesta (priorita' bassa);
    - rapporto "stato delle citta'" su richiesta: bisogni soddisfatti e no, aree comunali, industrie nuove
      (solo lettura e proposte, nessuna azione automatica).
    Non servono alla mod: traffico, semafori/attraversamenti, difficolta'/modalita'/campagna/editor.
6. Aggiornare questo file e `docs/prove-mappa-nuova.md` a ogni passo.

## 8. Cause di crash note (non ripetere)
- Scalo merci con marciapiedi merci negli slot passeggeri (74xxxxx): "Duplicate edges found" a quota -6 m.
  Schema giusto: `3701980` main_building_1_cargo, `64000xx` platform_cargo_era_c, `84020xx` binario,
  xx = -10..20, `tracks=1, length=3, specialization=1`. Altre misure: prima copiarle da uno scalo fatto a mano (s22).
- Togliere binari insieme alla stazione collegata, o vendere veicoli insieme al deposito, nella stessa chiamata.
- File azioni rimasti dopo una ricarica (vedi punto 2).
- Piu' prove rischiose nello stesso file: non si capisce quale ha causato il crash.

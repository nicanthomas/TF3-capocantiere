# STATO DEL PROGETTO — leggere per primo (aggiornato 13.10.2026)

Questo file permette a una chat nuova di ripartire senza rileggere le conversazioni precedenti. **All'avvio di QUALSIASI chat Claude o ChatGPT leggere prima `HANDOFF.md` dalla branch GitHub aggiornata**: contiene il checkpoint operativo, il prompt unico di avvio e le regole di aggiornamento continuo senza preavviso al cambio AI/chat. Poi leggere questo file per le regole vincolanti e lo stato tecnico. Questa procedura riguarda lo sviluppo e non introduce automazioni nel gioco.
Struttura del repo (dal 09.10.2026): nella radice anche `HANDOFF.md` oltre a `mod/`, `middleware/`, `README.md`, `LICENSE`; tutto lo
sviluppo e' in `dev-notes/` (codice: `cc_lib.lua`, `build_script.py`, `bozza/`, `sonde/`, `prove/`, `strumenti/`;
note: `dev-notes/note/`, compreso questo file). I comandi di questo file usano questi percorsi.
Dettagli: `dev-notes/note/prove-mappa-nuova.md` (cronologia prove), `dev-notes/note/studio-salvataggio-terzi.md` e `dev-notes/note/scoperte-api.md`
(API verificate), `dev-notes/bozza/README.md` (cosa c'e' in ogni file della bozza).

## 1. Regole di Nicolo' (vincolanti)
- WORKFLOW MULTI-AI (09.10.2026): Claude, ChatGPT e loro nuove conversazioni possono subentrare **senza preavviso** alla fine di crediti o contesto. Ogni AI deve leggere `HANDOFF.md` all'avvio e aggiornare/pubblicare un checkpoint **dopo ogni passo significativo** durante la sessione, non solo alla fine. Aggiornare lo stato tecnico qui quando cambia. Non presumere che l'altra AI abbia completato attività non pubblicate. Nessun processo in background è autorizzato per gli handoff.
- Rispondere in italiano, al massimo una domanda per volta, lavorare in autonomia. Non inventare l'API: provarla.
- Sul PC scrivere SOLO nella cartella `mods` e in `capocantiere` (dati utente). Backup prima di modificare un file
  esistente. Non cancellare nulla. Chiedere prima di toccare altre cartelle.
- Chiave API: mai usarla ne' ripeterla (Nicolo' ha impostato ANTHROPIC_API_KEY da solo).
- GitHub: Claude usa Composio (`GITHUB_COMMIT_MULTIPLE_FILES`) quando disponibile; ChatGPT usa il proprio connettore GitHub autorizzato quando disponibile. Repository `nicanthomas/TF3-capocantiere`; branch di riferimento `main`. Titolo commit `gg.mm.aaaa-NR-Descrizione`; verificare SHA dei blob/commit dopo la pubblicazione. Non usare un'API o un accesso non realmente disponibili e non sovrascrivere commit altrui. Niente pull request (regola di Nicolo', 09.10.2026): l'AI che sta lavorando (Claude o ChatGPT) fa da sola commit, push e merge in `main`, senza aprire PR e senza chiedere; prima del merge test automatici verdi e controllo che `main` remoto non sia cambiato; nelle note dichiarare cosa NON e' ancora provato in TF3.
- Partita: modalita' creativa, anno >= 2020. Tutto quello che si piazza deve FUNZIONARE (anche i depositi).
  Restare dentro i confini della mappa.
- Crash: la partita e' salvata; chiudere il gioco, riaprirlo e ricaricare da soli (sequenza al punto 4).
- COMMIT: titolo CORTO `gg.mm.aaaa-NR-Descrizione` (max ~70 caratteri), dettagli nel corpo del messaggio.
  La GitHub Actions (`.github/workflows/test.yml`) lancia a ogni push i test del middleware (33 dal 09.10.2026), i 65 controlli del
  mock, `build_script.py --check` (solo avviso) e controlla che la mod nel repo abbia DEV_MODE = false.
- DEV_MODE (08.10.2026): la mod in `mod/` ha DEV_MODE = false. Sonde e prove richiedono DEV_MODE = true: sul PC di
  prova si installa SEMPRE la copia di `python dev-notes/build_script.py --dev [--bozza]` (dist/tfcapocantiere_1_dev,
  da copiare come `tfcapocantiere_1`, backup prima). La mod gia' installata stasera (v13) ha ancora DEV_MODE = true.
- GITHUB SEMPRE AGGIORNATO (08.10.2026): dopo ogni passo concluso (prova riuscita o fallita, sonda letta,
  correzione) fare subito il commit, senza accumulare. Tenere allineati col tempo anche: `README.md` (tabella delle
  azioni con lo stato "Provato in gioco", requisiti, costo per sessione quando misurato), questo file (sezioni 5-8)
  e `dev-notes/note/prove-mappa-nuova.md`. Quando la v14 e' provata: release su GitHub con lo zip di
  `python dev-notes/build_script.py --release` (DEV_MODE spento), screenshot o GIF di una richiesta trasformata in
  costruzione nel README, costo medio di una sessione nel README. Push nel modo piu' economico (verificato 08.10):
  nel workbench di Composio `git clone https://github.com/nicanthomas/TF3-capocantiere.git` (repo pubblico), applicare
  la patch compressa (`git diff -U0`, gzip+base64; `git apply --unidiff-zero`), confrontare l'impronta di tutti i
  file con quella locale, poi `GITHUB_COMMIT_MULTIPLE_FILES` con upserts/deletes letti dal disco del workbench.
- PRINCIPIO GENERALE (08.10.2026): la mod e il middleware agiscono SOLO dopo un input esplicito di Nicolo'.
  Nessuna azione automatica, programmata o in background nel gioco (niente cicli che costruiscono, comprano,
  vendono o modificano da soli). Ogni costruzione, acquisto o modifica parte da una sua richiesta e finisce li'
  (il collaudo subito dopo una costruzione fa parte della stessa richiesta e non cambia nulla).
- RISPARMIO CREDITI (richiesta 08.10.2026): poche chiamate, piu' prove senza rischio nello stesso file azioni, le
  prove rischiose da sole; screenshot solo se serve (crash); se un servizio non risponde fermarsi e scriverlo invece
  di aspettare; non rileggere file grandi interi.
- LAVORO DA SOLO / DI NOTTE (regola del 09.10.2026, dopo una notte persa: 6 ore bloccate su una richiesta di
  permesso e PC lasciato acceso col gioco aperto):
  1. Quando Nicolo' non c'e' NON fare MAI richieste che aspettano la sua approvazione (permesso del computer,
     cartelle, cancellazioni): restano ferme finche' lui risponde. Se un permesso manca, andare avanti con quello
     che si puo' fare senza e scriverlo nelle note.
  2. Il permesso di controllo del PC SCADE dopo 30 minuti senza azioni sul PC (e puo' sparire quando il collegamento
     si riconnette): tenerlo vivo con un'azione leggera (screenshot piccolo, `scale` 0.3) almeno ogni 20 minuti, e
     chiederlo di nuovo SOLO se Nicolo' e' presente.
  3. Chiusura del gioco a fine lavoro: deve esserci un modo che NON dipende dal permesso del PC (da trovare e provare
     PRIMA di una notte da solo, es. comando dalla mod). Se a fine lavoro non si puo' chiudere, scriverlo subito a
     Nicolo' invece di aspettare.
  4. Prima di lasciare il lavoro a una notte da solo: verificare che i punti 2 e 3 funzionino.
  5. STOP / ORA DI FINE (regola ribadita il 14.10.2026, dopo che Claude il 13.10 ha detto «capito» e poi ha lasciato
     TF3 e Steam aperti e una richiesta di permesso in attesa tutta la notte). Quando Nicolo' chiede di fermarsi,
     chiudere le app e spegnersi, in quest'ordine e senza aggiungere altro:
     a. smettere di lavorare (niente nuove prove o idee);
     b. pubblicare su GitHub lo stato vero;
     c. chiudere TF3 e VERIFICARE che sia chiuso: `capocantiere_state.lua` non si aggiorna piu' e Steam mostra
        «GIOCA» (non «FERMA» o «Arresto»). «Torna al desktop» da solo NON basta: con il wrapper di Steam il processo
        o la console possono restare vivi;
     d. chiudere Steam se richiesto («tutte le app»), e verificarlo;
     e. MAI fare una richiesta di permesso nuova durante la chiusura: se un passo richiede un permesso che non c'e',
        scriverlo subito a Nicolo' e chiudere la sessione;
     f. scrivere a Nicolo' solo cio' che e' stato verificato; quello che non si e' potuto verificare va detto come tale.

## 1b. Avvio della chat: chiedere SUBITO tutte le autorizzazioni (una volta sola, all'inizio)
0. **VERIFICARE I PERCORSI (08.10.2026)**: Nicolo' ha spostato la cartella di INSTALLAZIONE del gioco fuori da C:
   (spazio finito). Tutti i percorsi di questo file (cartella `capocantiere`, `mods`, `crash_dump`) erano in
   `C:\Program Files (x86)\Steam\userdata\<steam-id>\3493540\local\`. Di solito spostare il gioco in un'altra
   libreria Steam NON sposta `userdata` (resta nella cartella di Steam), ma va verificato:
   - `<steam-id>` = l'unica cartella numerica in `C:\Program Files (x86)\Steam\userdata\` (trovarla con
     `device_list_dir`; l'ID non si scrive nel repo). Il middleware la trova da solo (`find_default_dir`).
   - controllare con `device_list_dir` se `...\local\mods\tfcapocantiere_1`, `...\local\capocantiere` e
     `...\local\crash_dump` esistono ancora; se no, cercare la nuova posizione (nuova cartella di Steam o della
     libreria) e chiedere l'accesso a quella;
   - se la cartella `mods` usata dal gioco e' cambiata, COPIARE la mod `tfcapocantiere_1` nella nuova cartella `mods`
     (prima backup; l'originale NON si cancella senza chiedere: regola "non cancellare nulla") e verificare nel
     gioco che la mod risulti attiva;
   - aggiornare in questo file e in `middleware/game_bridge.py` (DEFAULT_DIR o variabile CAPOCANTIERE_DIR) i
     percorsi nuovi, poi proseguire.
Vale per Claude e per ChatGPT (regola di Nicolo', 12.10.2026): all'inizio di ogni sessione chiedere in un solo
messaggio TUTTE le autorizzazioni necessarie per la prossima operazione, comprese le prove in TF3 (avviare il gioco,
caricare la partita, costruire, installare mod/middleware sul PC, usare la console). Mai saltare una prova in gioco
perche' l'autorizzazione non e' stata chiesta. Dettagli in `HANDOFF.md`, procedura di avvio punto 5.
Prima di qualsiasi prova, in un unico giro, cosi' Nicolo' puo' approvare tutto e poi lasciare lavorare:
1. Controllo del computer (`request_access`): Transport Fever 3 e Steam (servono per la ripresa dopo un crash).
2. Cartella `C:\Program Files (x86)\Steam\userdata\<steam-id>\3493540\local\capocantiere` (lettura/scrittura) e,
   se non e' gia' dentro, `...\3493540\local\crash_dump` (sola lettura del log dei crash).
3. Verificare con una chiamata leggera che il GitHub di Composio risponda (es. `GITHUB_GET_A_BRANCH` su main).
4. Clonare il repo (`git clone https://github.com/nicanthomas/TF3-capocantiere.git`, pubblico) e lanciare
   `cd dev-notes/bozza && python3 run_mock.py` (deve dare 65 ok).
Se qualcosa manca, dirlo subito in un solo messaggio, non a meta' lavoro.

## 1c. Configurazione locale Codex su Windows (10.10.2026)

Unico checkout E:\Sviluppo\TF3-capocantiere; Git 2.55.0.windows.5, Python 3.10.10, PowerShell funzionanti. Sviluppo checkout autorizzato, nessuna nuova installazione. Venv/fixtures nell'area work. Procedure controllo-grafico-windows.md/test-isolati-windows.md.

Flotta sorgenti corretta: count e dettagli coerenti dopo limite, fallback entro hardMax, ogni posizione controllata senza lunghezza di tabella sparsa. RED 3 errori Lua reali run 38045331676; GREEN 38045453402: Ubuntu 72 test/1 skip Windows, 14,349 s, mock normale 71 ok/0 falliti; Windows verde. Revisione senza blocchi. Mod non generata/installata, flotta NON provata in TF3.
Runner riproducibile test_isolati.py: venv -I -B obbligatori, fixtures uniche autorizzate, audit Python scritture/rete/processi/Steam, JSON espone skip/motivi. Locale **72 test OK**, 14,681 s, zero errori/fallimenti, 1 classe Lua skip per DLL assente; 8 nuove regressioni policy. Guardie non sandbox OS per codice nativo. Nota test-isolati-windows.md. CI completa verde run 38045943923: Ubuntu 80 test/1 skip, 15,233 s, Windows 72 test e classe Lua skip, mock normale 71 ok/0 falliti. Flotta e runner verificati prima di unire in main.
Gia' verificati: lock Lua Windows (5 regressioni incluso lettore Windows reale), wrapper ctypes (8 test ABI simulata), guardie desktop 14 anche -O; Steam screenshot/focus/ricerca/testo/ripristino provati, 12 Backspace totali, ricerca vuota/Pagina iniziale e frame stabile ispezionati. --rect CLI da screenshot recente, blocco anche pulsanti laterali e drift puntatore. SendInput globale mantiene race.
Falso verde mock corretto: fallimenti ora error/exit1; RED 38044823330 e GREEN 38044947518. Lua reale obbligatoria in CI Ubuntu. Windows manca DLL fidata 5.3/5.4 stessa architettura Python: nessuna installazione e nessun mock reale locale.
Barriera API Lua FATTO 11.10.2026: configure richiede anche lua_isinteger prima dello stato, escludendo
export standard 5.2 senza sottotipo intero; niente invocazione. Una regressione ABI simulata RED locale/CI
38134872906, GREEN 38134989337 Ubuntu 95 test/1 skip Windows, Windows 81/classe Lua skip,
mock 104 ok/0 falliti; locale isolato 81 OK/classe Lua skip, revisione senza blocchi.
Nota abi-lua-versioni.md: non certifica DLL/provenienza/architettura/versione futura, nessuna Lua 5.2
reale caricata e nessuna installazione. Runtime Windows fidato ancora assente.
Diagnosi statica PE FATTO 11.10.2026: lua_windows_diagnosi.py stdlib, header bounded, macchine
I386/AMD64/ARM64, flag DLL/magic/troncamenti e match macchina (non sola bitness). Nessuna ricerca,
variabile ambiente, DLL caricata o scrittura. Nove regressioni fixture RED 38135486992,
GREEN 38135628133 Ubuntu 104 test/1 skip Windows, Windows 90/classe Lua skip, mock 104 ok/0 falliti;
locale isolato 90 OK/classe Lua skip e revisione senza blocchi. Prova header Python reale senza
candidato: AMD64 64 bit, errors vuoto, runtime_loaded=false. Nota diagnosi-lua-windows.md.
NON certifica DLL, versione/export/dipendenze/fiducia; nessuna candidata reale e nessuna installazione.
Descrizioni read_map/check_line_fleet e SYSTEM_PROMPT_BOZZA allineate ai campi facoltativi;
available/errors per ramo, false/zero distinti da assenza, niente moltiplicatori/unita' o automazioni
inventati. Schemi/conferme/routing/Lua invariati. Locale 90 OK/classe Lua skip; GREEN 38136433834
Ubuntu 104 test/1 skip Windows, Windows 90/classe Lua skip, mock 104 ok/0 falliti; revisione statica
senza problemi. Nota descrizioni-dati-bozza.md, nessuna chiamata al modello o alla mod reale.
Runner isolato --require-lua opt-in FATTO 11.10.2026: default skip conservato, flag rende runtime
mancante errore/exit1, JSON lua_required. Tre bootstrap regression con policy setUpClass reale e
loader simulato: RED 38136828824 prima del codice; GREEN 38136991438 Ubuntu 107 test/1 skip Windows,
Windows 93/classe Lua skip, mock 104/0; locale default 93 OK/classe Lua skip, 16,212 s.
Prova reale flag senza runtime: exit1 atteso, 93 test/1 LuaUnavailable/zero skip, 16,111 s;
nessuna DLL caricata. Revisione senza problemi, isolamento/conferme invariati.
Nota lua-obbligatoria-isolata.md: manca ancora runtime nativo Windows fidato, non dire parita' raggiunta.
Parser userdata completo FATTO 11.10.2026: wrapper esatto function/data/return/end e nessun token residuo;
prima file troncati/wrapper errati o statement successivi apparivano validi. Quattro regressioni RED
38137476301 prima codice; GREEN 38137669139 Ubuntu 111/1 skip Windows, Windows 97/classe Lua skip,
mock 104/0; locale 97 OK/classe Lua skip, revisione senza blocchi. Nota parser-lua-completo.md.
Formati dichiarati/roundtrip/commenti conservati; subset, non parser Lua generale. Nessuna esecuzione
Lua o lettura di stato reale. Avviso build DIVERSO e mod invariata.
Validazione numeri finiti argomenti FATTO 11.10.2026: schema number+float NaN/Inf rifiutato
prima enum/bounds con errore fisso/percorso, interi arbitrari senza conversione float. Tre regressioni
pure RED38141026312 prima codice, GREEN38141250728 Ubuntu 144/1 skip Windows,14,110s; Windows 130/classe Lua skip,14,400s; mock104/0; locale130 OK/classe Lua
skip16,360s, revisione senza blocchi. Nota argomenti-numeri-finiti.md, nessun modello/bridge o schema
modificato. Continuazione fermata su richiesta di Nicolo': soltanto checkpoint/Git/rapporto dopo stop.
Chiavi userdata FATTO 11.10.2026: bool/nil/table rifiutati dal reader prima assegnazione, bool
rifiutati dal writer prima temp file. Bool VALORI preservati. Quattro regressioni RED 38140623855,
GREEN 38140784177 Ubuntu 141/1 skip Windows, 14,072 s; Windows 127/classe Lua skip, 14,236 s; mock 104/0, locale 127 OK/classe Lua skip, 16,280 s; revisione senza blocchi.
Nota parser-lua-chiavi.md: limite subset Python, boolkeys legali Lua ma collisioni True/1 e False/0;
floatkeys leggibili, writer int/stringa come prima. Solo fixture e stringhe; doc API corrette.
Terminatori Windows parser FATTO 11.10.2026: long literal normalizzati e primo newline ignorato
una sola volta, backslash+CRLF/LFCR normalizzato. Quattro regressioni RED 38140208979 prima codice,
GREEN 38140372898 Ubuntu 137/1 skip Windows, 14,028 s; Windows 123/classe Lua skip, 14,238 s; mock 104/0, locale 123 OK/classe Lua skip, 16,313 s; revisione senza blocchi.
Nota parser-lua-terminatori.md, solo stringhe, nessun file gioco o grammatica generale.
Screenshot GDI FATTO 11.10.2026: restore fallito blocca lettura, DC privato rilasciato prima bitmap.
Tre regressioni RED 38139758423, GREEN 38139928172 Ubuntu 133/1 skip Windows, Windows 119/classe
Lua skip; locale 119 OK/classe Lua skip, 16,280 s, mock 104/0, revisione senza blocchi.
Prova reale soltanto screenshot Steam: cinque BMP utilizzabili, GDI proprio processo 0 prima/dopo
tutte cinque, focus invariato, zero input/avvii TF3. Artefatti privati, nota screenshot-gdi-risorse.md.
Non certifica driver o recupero se falliscono DeleteDC/DeleteObject/ReleaseDC stessi.
Parser Unicode FATTO 11.10.2026: testo Unicode letterale invariato, byte escapati numerici
ricomposti UTF-8/fallback Latin-1 solo per sequenza; range byte e hex2 cifre. Sette regressioni,
RED 38139166979 e RED z da revisione 38139382189 prima fix; GREEN finale 38139535647 Ubuntu 130/1 skip Windows, 14,803 s; Windows 116/classe Lua skip, 14,494 s; mock 104/0,
locale 116 OK/classe Lua skip, 16,254 s, revisione approvata. Nota parser-lua-unicode.md.
Subset testuale Python, non API per byte arbitrari o grammatica generale; nessun dato reale.
Parser numeri/separatori FATTO 11.10.2026: interi decimali esatti senza float intermedio, numeri
finiti, meno separato soltanto numerico e separatori table obbligatori. Cinque regressioni RED
38138543778 prima codice, GREEN 38138777270 Ubuntu 123/1 skip Windows, Windows 109/classe Lua
skip; locale 109 OK/classe Lua skip, mock normale 104/0, revisione senza blocchi. Nota
parser-lua-numeri.md. Modello numerico Python distinto da Lua C++, nessun dato reale.
Sonda snapshot standalone FATTO 11.10.2026: sette regressioni fixture RED 38138031056 poi
GREEN 38138252617 Ubuntu 118/1 skip Windows, Windows 104/classe Lua skip, mock 104/0;
locale 104 OK/classe Lua skip. CLI normale/-O soltanto fixture, read_only=true/live_bridge_tested=false.
Nessun import game_bridge/env/ricerche/DLL o write/mkdir/cleanup; input esplicito nome stato,
regularfile/8MiB/firme path-fd e JSON conteggi/validita' senza dati privati. Revisione senza blocchi;
UNC sintattico/symlink finale NON certificano volume locale/junction o atomicita' OS. Counts soli elementi,
non entita' certificate. Nota sonda-bridge-lettura.md. Mai eseguita su file gioco/dati reali.

TF3 menu reale collaudato 10.10.2026 dopo autorizzazione distinta al ciclo opzioni Steam: doppio backup privato, wrapper disattivato temporaneamente nel campo, avvio normale, screenshot/focus/mouse, Esc a scancode torna al menu (virtual-key scan=0 senza effetto), uscita dall'icona Esci senza conferma, processo terminato. Due cicli senza partite/costruzioni; impostazioni del pannello non cambiate. Opzioni ORIGINALI ripristinate con confronto esatto dopo chiusura, wrapper/file gioco/mod/salvataggi non modificati dall'agente, nessuna chiave/Taskkill. Il wrapper originale resta attivo: non avviare senza ripetere il ciclo autorizzato. Note ripristino-opzioni-steam.md e controllo-grafico-windows.md. build --check --bozza resta DIVERSO/codice1, sintassi locale saltata, anche avviso CI; non dichiararlo verde.

GameBridge.send elimina risultati gia' letti: conciliare pulizia con divieto cancellazione prima di test vivi; non chiamato sui dati reali. Anche GameBridge.__init__ puo' creare la cartella dati con os.makedirs quando il prefisso e' attivo (lettura statica 11.10.2026): una sonda senza scritture deve evitare il costruttore, non basta evitare send. UI Automation Steam senza pulsanti; processi fuori sandbox. Screenshot privati solo locali.

## 1d. Ripresa autorizzata 12.10.2026 (ChatGPT)

Nicolo' ha autorizzato in questa chat checkout/rete, controllo Steam/TF3, cartelle mod/middleware/scambio,
log, backup/aggiornamento, avvio/chiusura normale, partita "capocantiere v14 prova", console con API
senza leggere o mostrare la chiave, pulizia soli file protocollo e ciclo opzioni Steam con ripristino se necessario.
Nicolo' ha scelto la linea bus Abriola-Maretto con numero stimato; costruita e collaudata il 12.10. Non sono permessi permanenti.

PROVATO IN TF3: trovato gioco nel menu principale; screenshot privato ispezionato, uscita normale
dall'icona Esci e processo terminato verificato. Nessuna nuova prova in partita finora.
SOLO TEST AUTOMATICI: suite Windows isolata 130 test, zero errori/fallimenti, una classe Lua saltata
per runtime mancante; 15,013 s. CI main 4c9624a verde, run 38273975189. Lua Windows reale NON provata.
Copia --dev --bozza generata dai sorgenti invariati di main: v14-bozza-4e61dfa4; sintassi locale saltata.
PROVATO SUL PC (fuori dal gioco): versione precedente riletta v14-bozza-32c86032 e avviatore 435 byte.
Con TF3 e console Python chiusi, backup integrali mod e middleware in cartelle adiacenti autorizzate,
confronto SHA256 dei backup riuscito; installati 5 file mod e 29 file middleware tracciati da main,
confronto SHA256 di ogni destinazione riuscito. La prima copia installata ha codice aggiornato ma due dichiarazioni di versione: TF3 usa 399dcf74.
Nessuna cancellazione manuale, nessun salvataggio modificato; opzioni Steam intatte.
Percorsi con identificativo Steam e rapporti backup conservati soltanto privatamente nell'area work della chat.
La mod in mod/ resta invariata DEV_MODE false; --check storico diverso, non dichiarare allineamento raggiunto.
PROVATO IN TF3: caricata la partita autorizzata; console pronta, zero chiamate API. state.lua riporta
399dcf74: trovate due dichiarazioni di versione dovute ai CRLF del checkout Windows. Console e gioco chiusi normalmente.
SOLO TEST AUTOMATICI: generatore corretto con quattro regressioni; suite finale 134 test, zero errori/fallimenti,
una classe Lua saltata, 16,195 s. CI 38275807791 verde, revisione senza blocchi, correzione c4afd72 integrata in main.
PROVATO SUL PC: copia corretta reinstallata con nuovo backup e confronto; una sola versione 4e61dfa4.
PROVATO IN TF3: secondo caricamento riuscito, stato fresco e console confermano v14-bozza-4e61dfa4.
Console reale/API: check_line_fleet su 74233 risponde, due bus ma tempi giro mancanti; nessun acquisto/vendita.
Una richiesta usa due chiamate API e 22670 token totali riportati, incluso caching; costo monetario non misurato.
Il collaudo pendente ha anche controllato 112827 inesistente (dato storico, nessuna costruzione). Dettagli in versione-mod-crlf.md.
PROVATO IN TF3: seconda lettura diretta dal middleware ha preservato cargo_quality.available=true,
rami passengers/cargo disponibili senza errori, averageQuality/countBad/countTotal zero,
isVeryBad false per passeggeri e true per merci; nessuna interpretazione di unita'/percentuali.
Lettura finale flotta 74233: ok=true, round_trip_s=228, interval_now_s=114, vehicles=2,
interval_target=240, target=1, change=-1; solo proposta, nessuna applicazione.
Console terminata normalmente con /esci, totale 22670 token per la sola richiesta API; letture dirette senza API.
TF3 messo in pausa; costruzione ancora in attesa della scelta concreta di Nicolo'.

## 2. Architettura
- Mod Lua `mod/tfcapocantiere_1` (versione installata nel gioco: v13) + middleware Python `middleware/` (Claude).
- Bozza delle funzioni nuove in `dev-notes/bozza/b1..b9` (provata in gioco con `sim_eval`, DEV_MODE). Diventera' v14 con
  `python dev-notes/build_script.py --bozza` (prima fare il backup della v13 nella cartella mods).
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
- Dati necessari (DA VERIFICARE con la sonda `dev-notes/sonde/s23_flotta.lua`, sola lettura): tempo di un giro o
  intervallo della linea, eta' e vita utile dei veicoli, capienza, passeggeri/merci in attesa alle fermate.
  NB: `api.engine.util.line.getFrequency` NON esiste; esistono getMaxFrequency, getLineCapacityUsages,
  calcLineStationThroughput. Non scrivere l'analisi su funzioni non provate.
- Per la sonda serve una linea con veicoli in movimento da qualche minuto di gioco: lanciarla dopo aver costruito
  una linea (es. bus p2) e lasciato correre il gioco. `python3 dev-notes/strumenti/step.py ID "" sonde/s23_flotta.lua`.

## 3. Ciclo di prova (dalla chat cloud)
1. `python3 dev-notes/strumenti/step.py ID "chiavi_da_leggere" prove/pX.lua[,sonde/sY.lua] [gruppo2 ...]`
   -> scrive `/mnt/user-data/outputs/cc/actions_ID_<nonce>.lua` (bozza + prove, ogni prova in pcall).
   Dalla 40420 rinominarlo `capocantiere_actions_ID_<nonce>.lua` (prefisso).
2. SendUserFile del file, poi `device_commit_files` in
   `C:\Program Files (x86)\Steam\userdata\<steam-id>\3493540\local\mod_presets\` (stesso nome).
3. Attendere ~5 s, `device_stage_files` di `capocantiere_results_ID_<nonce>.lua`, poi
   `python3 dev-notes/strumenti/show.py <file staged> [lunghezza]`.
4. Il risultato di una `sim_eval` arriva con l'azione ID+1 che contiene la chiave `gID_0`.
   Per risparmiare: mettere nell'azione ID+1 anche la prova successiva (se non rischiosa).
- Il bridge non ha `device_bash`: niente `ls` sul PC; `device_list_dir` della cartella e' enorme (evitarlo).
- Log del crash: `...\3493540\local\crash_dump\stdout.txt` (stage + grep "Duplicate|Assertion").

## 4. Ripresa dopo un crash (clic, schermo 1568x656 circa)
Exit sul dialogo (950,392) -> eventuale "Uscire dal gioco?" di Steam (779,340) -> Gioca (171,196) ->
Carica partita (540,560) -> "partita vuota di test" Carica (360,293) -> Avvia partita (1487,595).
Velocita': pausa (1404,648), massima (1456,648). Il salvataggio "partita vuota di test" e' quello INIZIALE
(1 gen 2020, lastActionId 0, mappa vuota): ogni ricarica cancella le prove fatte.

## 5. Stato del gioco al 08.10.2026 (sera)
- **CARTELLA DI SCAMBIO CAMBIATA (build 40420)**: la 40420 permette `app.*Userdata` solo su alcune cartelle del gioco
  (`mod_presets`, `biomes`, `heightmaps`, `towns_industries`; NON `capocantiere`, ne' sue sottocartelle). La mod installata
  (v13 + patch `ensureDir`, backup `capocantiere.script.lua.bak_20261008_v13` nella cartella della mod) scrive in
  `...\3493540\local\mod_presets\` con prefisso `capocantiere_`: `capocantiere_state.lua`,
  `capocantiere_actions_<id>_<nonce>.lua`, `capocantiere_results_<id>_<nonce>.lua`. Dettagli:
  `dev-notes/note/aggiornamento-40420.md`. FATTO (commit 49): `mod/` usa `DIR = "mod_presets"`, `FP = "capocantiere_"`;
  middleware (`game_bridge.py`: cartella `mod_presets`, prefisso, dati del middleware in `capocantiere`), test,
  `verifica_installazione.py`, `step.py` (scrive gia' `capocantiere_actions_...`).
- Accessi concessi in questa chat: `capocantiere`, `crash_dump`, `mods\tfcapocantiere_1`, `mod_presets`, computer
  (Transport Fever 3, Steam, transportfever3.exe). Il gioco e' su E:\SteamLibrary, i dati utente restano su C:.
- Studio della partita di terzi FATTO (punto 0): risultati in `dev-notes/schemi_terzi/` (README con il riassunto).
  Ultimo id usato sulla partita di terzi: 10 (non salvata).
- Poi caricata la "partita vuota di test" (dalla chat: nel salvataggio va disattivata la mod mancante "Scania R-Series -
  Base set", Mod -> filtro Mancanti -> Disattiva tutto). lastActionId era 0. id 1 = p23, id 2 = lettura: prossimo id 3.
- **09.10.2026 ore 08:40**: partita salvata come **"capocantiere v14 prova"** (contiene tutte le prove: p2, p4, p8, p14,
  p37, linee funzionanti) e ricaricata: gira la **v14 dev `v14-bozza-32c86032`** (state.lua: `modVersion`, `speed`).
  Gioco in PAUSA (speed 0). Con la v14 `lastActionId` riparte da **0** a ogni caricamento (non sta nel salvataggio):
  id 1 e 2 usati per il collaudo (vedi sotto); prossimo id **3**. File azioni rimasti: solo
  `capocantiere_actions_24_bf4c0219.lua` con `actions = {}` (innocuo; il middleware lo sposta in `vecchi` all'avvio).
- ATTENZIONE (09.10.2026): un `device_commit_files` aveva installato una copia VECCHIA della mod (1db6fb1e invece di
  32c86032, file in outputs non aggiornato al momento dell'invio). Dopo ogni installazione rileggere il file dal PC
  (`device_stage_files`) e confrontare lo sha1 con dist/.
- Il permesso di controllo del PC **scade dopo 30 minuti senza azioni sul PC** (e a volte si perde quando il
  collegamento si riconnette): rifarlo (resolve + request) solo quando serve davvero, perche' la richiesta resta
  in attesa finche' Nicolo' non risponde.
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
| Linea merci su strada con le stazioni INTEGRATE delle industrie (`connect_industry_to_city`) | p37 | 09.10, collaudo ok |
| Treno merci industria -> industria (`build_cargo_rail_line`) | p4 | 09.10, collaudo ok (5944 m) |
| Rete merci (`build_cargo_rail_network`), binario d'attesa facoltativo | p14 | 09.10, collaudo ok, 1 treno |
| Segnali da script a senso unico e a doppio senso (`CC.placeSignals`/`CC.addSignals`) | p34, p38, p39 | 09.10: 5 segnali su una linea |

## 7. Da fare (in ordine)
0. **FATTO 08.10.2026** (risultati in `dev-notes/schemi_terzi/`). Era: studio COMPLETO del salvataggio di terzi (accesso UNA SOLA VOLTA, sola lettura). Nel primo studio (07.10)
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
   - Salvare i risultati NEL REPO (questa volta si', compressi o riassunti se grandi) in `dev-notes/schemi_terzi/`, e
     riportare gli schemi utili nella bozza (CC.TEMPLATES, schemi scali, segnale). Poi la chat carica DA SOLA
     la "partita vuota di test" (nessuna mod da disattivare; clic come nella sezione 4, partendo
     dal menu principale: Esc/menu -> Esci al menu, poi Carica partita).
1. **p23 RIUSCITA (08.10.2026)**: scalo merci (1 binario, 160 m) vicino alla "Raffineria di petrolio di Maretto", costruzione 89548, gruppo 89601, 2 estremi, nessun crash (build 40420). Era: scalo merci con lo schema copiato (`CC.cargoStationBuilder`, slot 64xxxxx). Rischio crash: da sola.
   `python3 dev-notes/strumenti/step.py 8 "" prove/p23_scalo_merci.lua`
1a. **IN CORSO (08.10.2026 sera)**: segnali da script VERIFICATI (p26-p34, vedi scoperte-api.md, `CC.placeSignals` /
    `CC.addSignals` in b6). Doppio binario: la diramazione subito fuori dalla stazione collide (p36) -> nuovo schema:
    binari della stazione NON uniti, tratto dritto di 140 m, binario 1 col tracciato normale, binario 2 PARALLELO
    (`CC.parallelTrack`, metodo della mod "Parallel Tracks"), segnali a senso unico dopo i due binari. Prova: p35.
    Era: **Anello ferroviario con binari adeguati (richiesta di Nicolo' 08.10.2026)**: l'anello provato ieri aveva un solo
    binario per i due sensi. Voluto: (A) 2 binari, uno per senso, oppure (B) 1 binario con tratti a doppio binario
    per l'incrocio dei treni. Ordine:
    1. segnale copiato dal salvataggio di terzi (punto 0, sonde s26/s8) oppure piazzato A MANO su un binario, poi sonda
       `s8_segnali.lua` (ora cerca i binari con l'octree) per copiare come si piazza da script (`CC.SIGNAL_MODEL`, `CC.addSignals` in b6 sono da verificare);
    2. opzione A: `build_rail_ring` con `double_track = true` (usa `CC.linkStationsDouble`, segnali a senso unico),
       2 linee (una per senso), piu' treni per senso; collaudo e far correre il gioco;
    3. opzione B: binario unico + `CC.buildPassingLoop` (b6) fuori dalle stazioni, con segnali agli scambi.
    Ripiego senza segnali: binario unico con stazioni a 2 binari (incrocio in stazione), valido con pochi treni.
    **Stato 09.10.2026 mattina**: binario 2 parallelo con strade spezzate nella stessa proposta (OK: 7 strade
    spezzate), lati degli estremi decisi sulle direzioni vere (`linkDouble`); il binario 1 pero' si costruisce solo a
    volte (5,2-5,8 km con 21-41 ponti: "Curvatura eccessiva"/"Costruzione non consentita" a seconda degli estremi) e il
    parallelo urta altre strade di campagna. DA RIPRENDERE con una mappa pulita; intanto l'anello a binario unico
    (incrocio nelle stazioni, p12/p24/p25) resta la soluzione che funziona, ora con i segnali disponibili.
1b. **FATTO 09.10.2026 (s35 + p37)**: ogni industria a terra ha una stazione per CAMION integrata (non del giocatore);
    piattaforme petrolifere e aree di pesca hanno stazioni per NAVI (e un eliporto); nessuna stazione ferroviaria
    integrata. `connect_industry_to_city` le usa gia' (p37 ok). Per i treni: scalo merci cercato vicino alla stazione
    integrata (`CC.industryAnchor`), non al centro dell'industria (per le fattorie era troppo lontano).
    Era: **Stazioni integrate nei siti industriali (novita' TF3)**: sonda (sola lettura) per capire se le industrie hanno
    gia' una stazione propria utilizzabile in una linea (gruppo/stazione/terminali, mezzi serviti, bacino). Se si':
    le linee merci usano quelle invece di costruire scali (meno costruzioni, meno rischio di crash).
2. **FATTO 09.10.2026**: p4 (mancava `CC.cargoFor`, aggiunta in b3) e p14 (binari d'attesa facoltativi: se non c'e'
   spazio, un treno solo con avviso). Segnali: id provvisorio dell'oggetto = -400000000 - posizione 0-based (p39).
3. **IN SOSPESO (09.10.2026)**: porto (p21, p40-p43): `harbor_modular.con` con i 5 moduli copiati dal porto di terzi
   viene RIFIUTATO senza messaggi (verifica a secco ok, nessuna collisione, ~866k di costo), in ogni orientamento,
   quota (terreno, 2, 0) e distanza dalla riva. Senza moduli si costruisce ma resta senza stazione; senza il molo
   `small_pier` (solo banchina + ingresso) si costruisce, ma 0 stazioni. Serve un porto FATTO A MANO da Nicolo' su
   questa mappa, poi la sonda s6 per copiarne moduli e posizione rispetto alla riva. Doppio binario su una linea
   (p13, `build_rail_line2` con `double_track`, 09.10.2026): fallisce ancora alla diramazione subito fuori dalla
   stazione ("Costruzione non consentita", 6 varianti). Lo schema dell'anello (binari della stazione non uniti) non
   basta per i capolinea: un treno che arriva sul binario 2 non puo' ripartire sul binario 1 senza un incrocio
   (comunicazione) fuori dalla stazione. DA FARE: comunicazione tra i due binari a 200-300 m dal capolinea.
4. **FATTO 09.10.2026**: p2 (bus tra citta'), p3 (aggiungi/togli/sostituisci veicoli), p8 (allunga linea: nella 40420
   `lc.stops` e' in sola lettura -> linea nuova `api.type.Line.new()` con tutte le fermate + `makeLineUpdateCmd`).
   Gioco fatto correre con `api.cmd.makeGameSetSpeedCmd(4)` da `lua_eval` (0 = pausa): i veicoli si muovono.
4b. **FATTO 09.10.2026** (s23, s36, p44): `SIM_ACTIONS.adjust_line_fleet` (b2) misura il giro dai tempi delle tratte
    dei veicoli (`TRANSPORT_VEHICLE.sectionTimes`, secondi; 0 = non ancora misurata) e calcola i veicoli per un passaggio
    ogni `interval` s; `apply` compra/vende la differenza; treni solo con `force`. Middleware: tool `check_line_fleet`
    (lettura) e `adjust_line_fleet` (con conferma) in `tools_bozza.py`. Altre funzioni utili trovate:
    `api.engine.util.line.getMaxFrequency`, `calcLineStationThroughput`, `getLineCapacityUsages`,
    `api.engine.util.vehicle.getVehicleCapacities`, `transportVehicleSystem.getLineCargoInfo`.
    Numero iniziale di veicoli alla creazione delle linee: UNITO in main il 09.10.2026
    (NON ancora provato in gioco): `CC.estimateFleet` / `CC.initialFleet` in b2 (distanza tra le fermate x
    fattore percorso, `metadata.<tipo>Vehicle.topSpeed` del modello o `CC.FLEET_SPEED`, sosta per fermata, passaggio
    ogni `CC.FLEET_INTERVAL`, limiti `CC.FLEET_MAX`); usata da build_intercity_bus, connect_station_to_town, linee di
    b4 (aerei/elicotteri/navi) e create_line_from_stations (treni: al massimo 2 senza numero esplicito). Il numero chiesto
    da Nicolo' vince sempre. Risultato con `fleet` (stima, giro, velocita'). Mock 71 OK. Prova in gioco: una linea bus
    senza num_vehicles, poi `check_line_fleet` dopo un giro per confrontare stima e misura; verificare `topSpeed`.
    FATTO 10.10.2026 sui sorgenti: adjust_line_fleet rifiuta interval fuori 60..3600 s e max fuori
    1..20/non finiti prima di leggere la linea, coerente con schema middleware; default ed estremi preservati.
    RED 38049622568, GREEN 38049721158: Ubuntu 91 test/1 skip Windows, Windows 80/classe Lua skip,
    mock 87 ok/0 falliti; locale isolato 80 OK. Nessun comando per input rifiutati. Wrapper b9 puo' ancora
    leggere gameSpeed: non dichiarare zero letture API. Nota flotta-convalida-argomenti.md; NON provato in TF3.
    FATTO 10.10.2026 sui sorgenti: tempi tratta non numerici/non positivi/non finiti esclusi;
    overflow di somma/media/giro diventa misura mancante, senza proposta/apply. Accumulo float 0.0
    evita wraparound intero; dati finiti dell'altro veicolo conservati, nessuna soglia fisica inventata.
    Due regressioni native e cinque mock; RED float 38050006467 e intero 38050265270, GREEN finale
    38050352916: Ubuntu 93 test/1 skip Windows, Windows 80/classe Lua skip, mock 92 ok/0 falliti.
    Locale isolato 80 OK/classe Lua skip; revisione finale senza blocchi. Nota flotta-tempi-finiti.md.
    NON provato in TF3, nessuna mod rigenerata/installata.
4c. Puntualita'/qualita' delle consegne: sonde storiche s37 (09.10.2026), nessuna nuova prova in gioco.
    FATTO 10.10.2026, sola lettura locale: api/tealdef/api/engine/util.d.tl dichiara CargoQualityData
    (countBad, countTotal integer; averageQuality number oppure nil; isVeryBad boolean),
    SummarizedCargoQualityData (passengers e cargo) e IndustryProductivityInfo
    (producing, boostFromRule, boostFromPersonCapacity boolean). I campi non sono piu' ignoti;
    unita'/intervallo di averageQuality e getProductionRating non dichiarati.
    getCargoProducedPerYear(stockListEntity, cargoTypeId) e getCargoQualityDataForLine(lineEntity,
    cargoTypeId) richiedono entrambi gli argomenti: possibile spiegazione statica dei precedenti can't be cast.
    Nella sonda storica 40420 INDUSTRY.stockList valeva l'id dell'industria: non riverificato.
    Nota qualita-merci-tipi-tf3.md con fonte, hash, firme e limiti. Percorso res/scripts inesistente
    in questa installazione; nessun file gioco modificato/estratto, nessun salvataggio letto.
    FATTO 10.10.2026 sui sorgenti: normalizzazione protetta CC.normalizeCargoQuality/lineCargoQuality
    in b8 e cargo_quality nel controllo flotta b2 solo per apply falso/assente, anche senza misura giro.
    Accessi espliciti pcall, nessuna enumerazione userdata/raw error, numeri finiti, zero/nil/false distinti.
    Tredici nuovi casi mock; un userdata Lua sintetico, NON C++ TF3. RED 38048874590 poi GREEN
    38049081989: Ubuntu 89 test/1 skip Windows, Windows 80/1 classe Lua skip, mock 84 ok/0 falliti.
    Locale isolato 80 OK/classe Lua skip. Nessun comando aggiunto, mod non rigenerata/installata.
    Linee senza veicoli mantengono il ritorno anticipato senza cargo_quality. Non inventare
    percentuali o moltiplicatori. Campi e semantica runtime ancora da sondare con partita autorizzata.
    FATTO 11.10.2026 sui sorgenti: CC.normalizeIndustryProductivity/industryProductivity in b8,
    tre booleani producing/boostFromRule/boostFromPersonCapacity protetti, false valido e nil/errori distinti.
    read_map aggiunge productivity alle industrie posizionate; API guasta/assente non cambia ok/mappa,
    nessun comando. Dodici mock e un userdata Lua sintetico, NON C++ TF3: RED 38134377278,
    GREEN 38134484171 Ubuntu 94 test/1 skip Windows, Windows 80/classe Lua skip, mock 104 ok/0 falliti.
    Locale isolato 80 OK/classe Lua skip, revisione senza blocchi. Nota produttivita-industrie.md.
    Significato boost e comportamento userdata ancora NON provati; mod non rigenerata/installata.
    Elenco delle funzioni api.engine.util: scoperte-api.md (09.10.2026).
5. **v14 CARICATA E COLLAUDATA nel protocollo normale (09.10.2026, 08:40)**: build `v14-bozza-32c86032` (`mod/` con
   DEV_MODE = false nel repo, `--check` OK; copia `--dev --bozza` installata e riletta dal PC: sha1 uguale a dist/).
   Backup nella cartella della mod: `.bak_20261009_v13patch` (v13 + patch) e `.bak_20261009_v14_1db6fb1e`.
   Prove con file azioni come quelli del middleware (niente sim_eval): id 1 `check_network` -> 4 linee, 4 ok;
   id 2 `adjust_line_fleet` (apply = false) sulla linea bus 89994 -> giro 1193 s, 6 bus, propone di toglierne 1;
   `read_map` -> confini, industrie, quote. Test automatici: middleware 30 OK, mock 65 OK.
   NON VERIFICATO: il middleware vero sul PC con Claude (serve la chiave API, che solo Nicolo' usa) e il costo di
   una sessione. DA FARE con Nicolo': `git pull` del repo sul PC, partita "capocantiere v14 prova" aperta,
   `set CAPOCANTIERE_BOZZA=1` e `middleware\avvia_capocantiere.bat`; 3 richieste di prova (una lettura, un
   check_line_fleet, una piccola costruzione) e annotare i token stampati dalla console.
5a. **FATTO 09.10.2026 (Claude, solo test senza gioco)**: robustezza del middleware ai timeout (`game_bridge.py`).
    Prima un timeout lasciava il file azioni nella cartella: la mod poteva eseguirlo piu' tardi (es. ripresa dal menu)
    e una seconda richiesta con lo stesso id creava due file `actions_<id>_*` (la mod ne sceglie uno a caso).
    Ora: prima di scrivere si ritirano in `vecchi` i file con lo stesso id; al timeout, se `lastActionId` < id, il file
    viene ritirato (`GameTimeout.status = "ritirata"`, si puo' riprovare); se la mod l'aveva gia' preso,
    `status = "accettata"` (non ripetere) e il risultato tardivo non viene cancellato da `_cleanup`: `main.py` lo
    consegna a Claude al turno dopo (`deliver_late_results`) e lo registra nel diario (annullabile). Test: 33 OK.
    NON provato in TF3.
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
6. Aggiornare questo file e `dev-notes/note/prove-mappa-nuova.md` a ogni passo.

## 8. Cause di crash note (non ripetere)
- Scalo merci con marciapiedi merci negli slot passeggeri (74xxxxx): "Duplicate edges found" a quota -6 m.
  Schema giusto: `3701980` main_building_1_cargo, `64000xx` platform_cargo_era_c, `84020xx` binario,
  xx = -10..20, `tracks=1, length=3, specialization=1`. Altre misure: prima copiarle da uno scalo fatto a mano (s22).
- Togliere binari insieme alla stazione collegata, o vendere veicoli insieme al deposito, nella stessa chiamata.
- File azioni rimasti dopo una ricarica (vedi punto 2).
- Annulla a gioco IN CORSO: gli id liberati vengono riusati subito (persone, veicoli...). `undo` ora tiene solo
  binari che sono ancora binari e costruzioni ancora del giocatore (09.10.2026); prima rischiava di toccare altro.
- Segnali: `comp.objects` con id provvisorio diverso da -400000000 - (indice 0-based in edgeObjectsToAdd) ->
  "Unknown exception" nel comando (non crash, ma nessun segnale).
- Piu' prove rischiose nello stesso file: non si capisce quale ha causato il crash.


### Bus Abriola-Maretto richiesto da Nicolo' (12.10, 18:36)

PROVATO IN TF3 con console/API reale e conferma: build_intercity_bus town_ids=[62682,62688],
num_vehicles omesso. Risposta grezza conservata privatamente, mod v14-bozza-4e61dfa4.
Linea 79575, nome effettivo Bus Passeggeri-Abr-Mar-IC-1 (name richiesto non rispettato), due fermate:
89790 riusata ad Abriola, 118254 costruita a Maretto. Deposito nuovo 80062; cinque eCitaro acquistati.
Stima iniziale: fleet.estimated=true, count=5, route_m=10084, round_trip_s=1002, interval_target=240,
top_speed_ms=22, speed_from_model=false: velocita' di fallback, non letta dal modello.
Il giro 1002 s e' stimato, NON misurato in servizio. Collaudo incorporato e check_line successivo ok=true,
problems=[]; EN_ROUTE=5, movement_unknown=5, vehicles_moving=0, stats=[]. Movimento/frequenza reali
ancora da verificare dopo avanzamento. Stato fresco conferma linea e cinque veicoli, lastActionId=2.
Richiesta: tre chiamate API, input 8, output 540, cache letta 22041, cache scritta 11447, totale 34036 token.
Costo monetario non misurato. Solo questa costruzione eseguita; flotta Lissone non modificata.

### Collaudo dopo il giro (12.10, 18:41)

PROVATO IN TF3, letture dirette senza ulteriori chiamate API: linea 79575, cinque bus, due fermate;
check_line ok=true, problems=[], quattro EN_ROUTE e uno AT_TERMINAL. Misura velocita'/movimento
ancora sconosciuta per i cinque bus, ma check_line_fleet ora ha tempi completi: giro 794 s,
intervallo attuale 158 s, target quattro bus per 240 s, change=-1. Proposta NON applicata.
Stima iniziale 1002 s conservativa rispetto al giro misurato in questa prova; cinque bus rimangono.
Qualita' passeggeri grezza: averageQuality=0.951716, countTotal=11, countBad=0, isVeryBad=false;
nessuna unita' dedotta. Non basta a certificare comportamento su tutte le mappe o profitto.

### Salvataggio e chiusura (12.10, 18:45)

PROVATO IN TF3: salvata con nome distinto 'capocantiere v14 Abriola-Maretto 12-10'; menu mostra il nuovo nome.
PROVATO SUL PC: file .sav presente (70739604 byte) e anteprima .jpg, data 18:43:30. Non ancora ricaricato.
TF3 chiuso dal menu Torna al desktop, console con /esci; processi entrambi assenti verificati.
Zero file capocantiere_actions residui; nessuna pulizia manuale. Opzioni Steam intatte.

### 12.10.2026, 19:40 — doppio binario riprovato realmente

Mod 509c3059 ricaricata. Su copia 'capocantiere test ferrovia 12-10', direttiva esplicita autorizzata:
anello Stern-Afforte-Abriola (terzetto di perimetro minimo), double_track=true, due sensi, un treno per senso.
PROVATO IN TF3: fallisce anello 1-2 sul secondo binario; primo binario 5484 m, 17 tratti su ponte e 39 in galleria.
Parallelo rifiutato per collisione con strade 84886 e 90350; tracciati alternativi rifiutati per dislivelli
vicino alla stazione o collisioni col primo binario. Tre stazioni e 98 tratti rimangono: pulizia prudente.
Nessuna linea o treno dell'anello completati. Nessuna rimozione manuale; risposta completa in
`dev-notes/note/prove-doppio-binario-12-10.json`. Non chiamare di nuovo sulla stessa copia contaminata.
Correzione velocita' in main 219e678, CI 38284903888 verde; nuova mod installata con backup e hash verificati.
PROVATO IN TF3: save bus ricaricato, 79575 e cinque bus presenti. Mod completa ancora NON finalizzata.

### Prova automatica reale del 12.10, 20:06

PROVATO IN TF3: build_air_or_water_line town_ids=[62685,62691], kind=harbor, numero navi omesso, conferma esplicita nel middleware. Entrambi i porti piccoli si costruiscono e generano stazioni (63463,63832). La prova fallisce poi: `nessun deposito/hangar per i veicoli`. Deposito di Lissone rifiutato nei tre punti di costa candidati (collisioni o messaggio vuoto). Nessuna linea o nave creata. Il middleware riporta pulizia di due costruzioni; porto GUI 122216 resta sulla mappa.

Questo risultato supera il vecchio blocco storico dei porti; non dimostra che funzionino su ogni costa. Non e' stata modificata la mod per questo esito: versione 509c3059. Risposta grezza in `prove-navale-12-10.json`.

Porto GUI salvato separatamente: `capocantiere porto GUI 12-10`, .sav 71091514 byte e .jpg 610344 byte verificati alle 20:04:04. Prossimo passo: deposito GUI per leggere quota/orientamento validi, quindi correggere soltanto cause confermate.

### Stop richiesto da Nicolo', 12.10.2026 20:11

PROVATO IN TF3 prima dello stop: deposito navale costruito dalla GUI, costruzione 122426, file `::/depots/water/water_depot.con`, un deposito e zero stazioni. Parametri seed=1, year=2027. Trasformazione X=(0.997749,-0.0670646), Y=(0.0670646,0.997749), origine=(-7558.78,-1680.23,2), acqua sul lato -Y60. Nessun acquisto nave e nessuna linea navale conclusa.

TF3 lasciato aperto sulla copia `capocantiere porto GUI 12-10`: il salvataggio verificato delle 20:04 precede questo deposito. Il deposito GUI e le variazioni successive NON sono salvati. Il porto GUI era stato salvato; originale e copie precedenti preservati. Nessuna modifica sorgenti dopo la correzione velocita' 219e678.

La sonda di percorso deposito/porto non e' stata eseguita: l'ordine `stop, update git` e' arrivato prima dell'avvio ed il controllo automatico ha respinto l'azione. Non aggirato. Nessuna conclusione sulla raggiungibilita' del deposito. Alla ripresa verificare prima lo stato reale del PC e conservare una nuova copia se ancora disponibile; poi diagnosi deposito e collaudo navi. Doppio binario ancora incompleto. Mod NON finalizzata.

### 13.10.2026 — causa quota deposito confermata in TF3

Stesso punto valido GUI: CC.placeTemplate rifiutato con terreno=0.0385056, riuscito con quota=2;
fonte ufficiale deposito forza superficie acqua+2. Costruzione 123741/deposito 120768, percorso
navigabile vero verso porto gruppo 115052. Save distinto 'capocantiere deposito quota 13-10'
verificato sul PC alle 06:39:52. Linea/nave ancora NON costruite, correzione stabile da integrare.
Dettagli in deposito-navale-quota.md. Non hardcodare 2 su ogni mappa: serve waterLevel reale.

### 13.10, 06:54 — mod navale corretta installata

PROVATO SUL PC: TF3 chiuso normalmente dal menu, gioco/console assenti prima di scrivere.
Generata --dev --bozza v14-bozza-0200b845; sintassi locale saltata per runtime Lua esterno assente,
CI Lua verde sullo stesso codice. Backup script installato verificato SHA256, nuovo script uguale
al generato, DEV_MODE true e una sola CC_VERSION. Middleware invariato, opzioni Steam intatte.
TF3 riavviato; prova completa ancora da eseguire su copia iniziale porto senza GUI aggiuntivi.

### 13.10, 07:00 — secondo blocco navale isolato

Con mod0200b845 la prova completa costruisce i porti ma non il deposito presso Lissone;
rollback due porti, nessuna nave/linea. La stessa funzione presso Calliano riesce (103939/118853).
Il codice cerca il deposito solo presso la prima città. Da provare tutte le città richieste in ordine,
fermarsi dopo successo; nessuna modifica geometrica necessaria per questo limite.
Dettagli ricerca-deposito-navale.md e risposta prove-navale-13-10.json. Deposito nuovo non salvato.

### 13.10, 07:09 — ricerca deposito corretta e installata

CI38349547194 verde Ubuntu/Windows; locale134test,0fallimenti/0errori, classeLua saltata,17.037s.
Revisione senza regressioni concrete; percorso deposito nuovo/porti ancora da verificare realmente.
Fix unito main7fe129b; --dev --bozza v14-bozza-4e8640b2 generata, installata a gioco/console chiusi
con backup e SHA256 uguali. TF3 riavviato. Nuovo save 'capocantiere deposito Calliano 13-10'
verificato07:06:53 (.sav71049690byte/.jpg583579). Copia iniziale porto preservata per nuova prova.
Nessuna linea/nave conclusa ancora; correzione sorgenti e installazione non equivalgono a collaudo completo.

### 13.10, 07:49 — estremi parallelo corretti; riavvio senza focus

Fix b6_binari unito main735f044: incroci stradali divisi anche sul primo/ultimo punto dopo
skipStart/skipEnd; nodo agganciato esistente escluso. CI38351450231 verde, mock117ok/0falliti,
Python locale134 senza errori/fallimenti e classe Lua saltata; revisione senza blocchi.
SOLO TEST AUTOMATICI: non installato/provato nel gioco. Nota parallelo-estremi-strade.md.
Chiusura normale TF3 tramite WM_CLOSE alla finestra verificata provata senza focus, nessun kill.
Prova avvio --script con percorso esterno rifiutata dal filesystem virtuale prima di eseguire
lo script; nessuna mappa caricata. Dialogo IOError chiuso normalmente; processo gioco assente.
Installata ancora4e8640b2. Richiesta minimizzazione AggiornamentiPC pendente, app mai modificata.

### 13.10 — prova completa navale e falso positivo percorso

Installata v14-bozza-56eb18f5 (include fix estremi binari), backup/hash verificati.
TF3 focus di nuovo disponibile; AggiornamentiPC assente, nessuna minimizzazione effettuata.
Porti121162/120860, deposito117738 costruiti. Nave118966 comprata ma non assegnabile a linea119497:
anche riprova stop0 e nextreachable-1 falliscono, nessun altro acquisto. Copia distinta nave fallita13-10
salvata tramite API ufficiale, callback/SAV/JPG verificati; originale e copia iniziale intatti.
API nativa getDetailedLineProblems segnala noPath a entrambe le fermate, mentre CC.hasPath generico
restituisce true: non certifica navigabilita' effettiva. Mod NON finalizzata, bacini vuoti.
Nota prova-navale-linea.md. Riavvio --script: risorsa eseguita ma manca data(), uscita non pulita;
dialoghi TF3 chiusi normalmente, processi assenti, manifest originale ripristinato con hash verificato.
Nessuna partita modificata da quelle sonde; non riprenderle durante i collaudi ora che focus funziona.


### 13.10, 20:53 — Solar in movimento, tratta Calliano ancora bloccata

PROVATO IN TF3: sulla copia separata, linea25246 temporaneamente fra due porti di Lissone125886/120311 accetta Solar123446; due campioni posizione distinti e velocita'8.333m/s. Tornando a Calliano123906 ricompaiono due percorsi mancanti. Accessi navali di tutti e tre porti registrati. Nessun acquisto aggiuntivo. Arrivo/servizio completo e linea tra citta' NON ancora dimostrati. Nuova copia Solar baia Lissone13-10 salvata e SAV/JPG verificati; copia due modelli preserva tratta originale e navi non assegnate. Dettagli prova-navale-linea.md. Mod non finalizzata.


### 13.10, 21:15 — guardia preacquisto e getter installati; campioni persi

Main39/42 integrati dopo CI verde e revisione: rotta navale nativa obbligatoria prima acquisto, posizione veicoli dal getter SDK. Installata d15a0424 con backup/hash a gioco chiuso. PROVATO IN TF3: copia Solar primo porto ricaricata, nave AT_TERMINAL poi EN_ROUTE, getter legge posizione reale. Controllo ripetuto resta movement_unknown1 perché campioni non persistono fra richieste: lavoro aperto. Tratta Calliano e anello non conclusi. Note prova-navale-linea.md.

### 13.10, 21:40 — campioni movimento persistenti PROVATI IN TF3 (Claude)

Commit 47 (st.samples via state:get/set + motivi movement_unknown). Installata v14-bozza-303c0edf con backup/hash.
PROVATO IN TF3 su copia Solar primo porto: 1a check_line no_previous, 2a vehicles_moving=1. Dettagli prova-navale-linea.md.

### 14.10 — rettifica chiusura del 13.10 e orientamento porti (Claude, senza PC)

RETTIFICA: il commit 50 («TF3 chiuso») e la sezione di handoff di Claude dicevano TF3 chiuso: NON verificato e falso.
Nicolo' il 14.10 mattina ha trovato TF3 e Steam aperti e la sessione Claude ancora attiva (richiesta di permesso
rimasta in attesa dalle 21:52 alle 06:04). Regola di chiusura aggiunta alla sezione 1 (LAVORO DA SOLO, punto 5).
SOLO TEST AUTOMATICI: i porti ora guardano la normale della costa (`CC.coastNormal`, b4) invece del raggio
citta'->costa; mock 150 ok. NON provato in TF3; sonda s41 pronta per verificarlo. Dettagli prova-navale-linea.md.


### 14.10 — sonda normale costa: errori distinti da terreno asciutto (ChatGPT)

SOLO TEST AUTOMATICI Linux/Lua5.4: s41 riporta disponibilita', letture valide/errori;
non produce normale/frazione con campioni incompleti. Sei regressioni fallivano prima,
ora passano. Suite locale154test/1skipWindows e mock150 verdi; build --check DIVERSO
preesistente. Nessuna nuova prova TF3, mod NON rigenerata/installata.
Accesso a tutto autorizzato in questa chat, ma collegamento PC tecnicamente assente.
Calliano e anello restano aperti; nota sonda-normale-letture.md e prova-navale-linea.md.

CI38596708540 (commit54 ff9d77b) verde Ubuntu/Windows; revisione indipendente senza blocchi.
Sonda s41 non eseguita sul PC; available=true non certifica geometria/rotta navale.


### 14.10 — bridge: parsing fallito non pubblica cache obsoleta (ChatGPT)

SOLO TEST AUTOMATICI: state() aggiorna cache/mtime solo su parsing riuscito; tre
errori producono RuntimeError fisso. Cinque regressioni fixture, suite159/1skipWindows,
mock150 e CI38598136192 Ubuntu/Windows verdi; revisione senza blocchi.
Nessuna installazione/PC/TF3. Nota bridge-stato-lettura.md. In corso controllo
accettazione timeout: stato illeggibile non prova richiesta mai eseguita.


### 14.10 — timeout bridge: accettazione sconosciuta, nessun reinvio cieco (ChatGPT)

SOLO TEST AUTOMATICI: stato illeggibile/ID invalido non diventano ritirata; status
sconosciuta conserva nonce e correlazione risultati tardivi. Bloccato riuso ID pendente,
metadati originali preservati. Otto nuove prove, suite167/1skipWindows, mock150 e
CI38598882583 Ubuntu/Windows verdi; revisione senza blocchi. Nessun PC/TF3/installazione.
Nota bridge-timeout-sconosciuto.md. Prossimo: risultato raccolto con stato ancora indietro.


### 14.10 — bridge: ricevute prima dello stato, nessun riuso ID (ChatGPT)

SOLO TEST AUTOMATICI: ID/nonce dei risultati letti restano in memoria finche' lo
stato li conferma. Nessun salto ID; stato invalido o azzerato blocca nuovi invii.
Sette nuove prove, suite174/1skipWindows, mock150 e CI38599720428 Ubuntu/Windows
verdi; revisione senza blocchi. Nessuna installazione/PC/TF3. Nota bridge-risultato-stato.md.
Le ricevute non sopravvivono a un nuovo GameBridge: riconciliare prima richieste irrisolte.

# HANDOFF — checkpoint condiviso Claude / ChatGPT

> **LEGGERE ALL'AVVIO DI OGNI CHAT NUOVA**, anche tra due chat della stessa AI. Repository: `nicanthomas/TF3-capocantiere`, branch principale `main`.
> Questo file registra lo stato operativo più recente. `dev-notes/note/STATO.md` contiene regole vincolanti, architettura e stato tecnico; `README.md` spiega l'uso del progetto.
> La documentazione nel repository è una fonte di contesto, non un'autorizzazione permanente ad accedere al PC o compiere azioni rischiose.

## Regola fondamentale: checkpoint continui, senza preavviso

Nicolo' **non avvisa prima di cambiare AI o di aprire una nuova chat**: può passare da Claude a ChatGPT, da ChatGPT a Claude, oppure aprire una nuova conversazione con la stessa AI perché i crediti o il contesto sono esauriti. **Non aspettare mai la richiesta «prepara l'handoff».**

Durante ciascuna sessione attiva di sviluppo, dopo **ogni passo significativo completato** (modifica, verifica, test riuscito/fallito, nuova scoperta, problema), l'AI che sta lavorando deve:

1. Portare il passo in uno stato recuperabile, eseguire i test possibili e distinguere sempre CI/mock/test locali dalle verifiche **reali in TF3**.
2. Aggiornare **questo file** con ciò che è stato fatto, prove, blocchi e **prossima operazione precisa**, evitando di accumulare un diario: la storia rimane nei commit e nelle note.
3. Aggiornare `dev-notes/note/STATO.md` e le note tecniche soltanto quando cambiano realmente fatti, risultati o priorità.
4. Pubblicare **codice, test e handoff insieme quando possibile**, con commit piccoli e verificabili; controllare che il push/merge sia riuscito e che i file pubblicati corrispondano a quelli voluti.
5. Solo dopo iniziare il passo seguente. Prima di un'operazione lunga o rischiosa, lasciare un checkpoint utile.

I checkpoint sono parte del lavoro richiesto, non un processo in background. **Nessuna AI può proseguire o aggiornare GitHub da sola dopo l'esaurimento dei crediti o la chiusura della chat.** Il lavoro non ancora pubblicato potrebbe andare perso: ridurre il rischio con commit frequenti.

## Regole di collaborazione

- **Una sola AI modifica il lavoro attivo per volta**. Non presumere che l'altra sia ferma: verificare lo stato remoto immediatamente prima di scrivere; se la branch è cambiata, integrare e riconciliare prima. Non eseguire force-push.
- Entrambe possono sviluppare Python, Lua, test e documentazione e pubblicare usando **gli strumenti GitHub effettivamente collegati e autorizzati nella sessione**. La procedura Composio documentata in `STATO.md` resta valida per Claude dove disponibile; ChatGPT può usare il proprio connettore GitHub. Non assumere capacità di scrittura se il connettore è solo lettura.
- **Niente pull request (regola di Nicolo', 09.10.2026)**: l'AI che sta lavorando (Claude o ChatGPT) fa da sola commit, push e merge in `main`, senza aprire PR e senza chiedere. Prima del merge: test automatici verdi e controllo che `main` remoto non sia cambiato nel frattempo (se e' cambiato, integrare prima). Una branch di lavoro serve solo durante il passo e va unita a `main` appena il passo e' concluso. Nelle note si dichiara sempre cosa NON e' ancora provato in TF3.
- L'accesso a GitHub **non equivale** a controllo del PC. Verificare ogni volta accesso a Windows, Steam, file locali, salvataggi e TF3. Permessi temporanei di una chat precedente non sono validi automaticamente.
- Non descrivere come testato in gioco qualcosa esaminato staticamente o provato soltanto con mock/CI. Non inventare API, esiti, commit o stato della partita.
- Non eseguire nel gioco azioni autonome non richieste; il sistema Capo Cantiere opera soltanto su direttive esplicite di Nicolo'. Mantenere approvazioni e restrizioni in `STATO.md`.
- Mai inserire credenziali, chiavi API, identificativi personali o informazioni sensibili nel repository.
- Se un accesso o un permesso manca e Nicolo' è assente, evitare richieste bloccanti: documentare l'ostacolo e procedere con quanto consentito.

## Procedura di avvio — identica per Claude e ChatGPT, anche in una chat vuota

1. Aprire il repository `https://github.com/nicanthomas/TF3-capocantiere` e verificare branch, head SHA e commit recenti. **Non fidarsi di un SHA storico contenuto nei documenti senza controllarlo**.
2. Leggere per intero `HANDOFF.md`, poi le regole e le sezioni pertinenti di `dev-notes/note/STATO.md`; quindi i file di codice e le note citati dalla prossima attività.
3. Confrontare il checkpoint con gli ultimi commit; se è obsoleto, ricostruire gli aggiornamenti dai commit senza sovrascrivere modifiche recenti.
4. Verificare i propri accessi reali. In assenza di PC, proseguire con revisione codice, sviluppo e test eseguibili senza gioco; rimandare le verifiche TF3 dichiarandole non eseguite.
5. Riprendere **autonomamente** dalla prossima operazione concreta riportata sotto. Se manca una priorità utilizzabile, scegliere il più piccolo passo utile e sicuro da `STATO.md`, senza chiedere a Nicolo' di ricostruire il contesto.
6. Aggiornare e pubblicare questo handoff **durante** il lavoro dopo ogni passo significativo. Non attendere un messaggio di cambio AI.

## CHECKPOINT OPERATIVO CORRENTE

**Stato:** 10.10.2026 (Codex locale Windows). Installazione Git tramite winget autorizzata e riuscita: `git version 2.55.0.windows.5`. Unico checkout creato in `E:\Sviluppo\TF3-capocantiere`; prima della clonazione non esistevano ne' la destinazione ne' il genitore E:\Sviluppo. Nessun file preesistente sovrascritto.
Checkout pulito su main, origin corretto; ultimo confronto prima di questo checkpoint: HEAD locale e main remoto entrambi `179ad13b57e14d23a233a2dd513c29d97f37fc53` (08). CI 08 verde, run 38042444275. Pubblicazione via connettore GitHub seguita da fetch/fast-forward locale, senza PR/force-push. Nessun AGENTS.md trovato nel checkout o nei genitori controllati.
Intera suite Python eseguita dal checkout in venv senza pacchetti aggiuntivi, con fixtures solo in work/tf3-python-isolated, API disabilitata, rete e accessi Steam bloccati da audit hook. Ultima esecuzione: **37/37 OK**, 14,478 s, zero errori/fallimenti. Primo giro: 36 OK e 1 WinError 5 in test_log_schedule_and_due_checks. Diagnosi su file separato: os.replace fallisce con un lettore Windows aperto e riesce dopo la sua chiusura; il mock legge/scrive state.lua da due thread senza sincronizzazione. Problema intermittente NON corretto: il secondo giro verde non dimostra stabilita' su Windows. Nessun sorgente del repository o bridge installato modificato. Nessuna modifica a mod installata, salvataggi o file del gioco; nessuna azione inviata al gioco.

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | ChatGPT / Codex desktop, controlli locali Windows |
| Branch | solo `main` (le branch `lavoro/flotta-iniziale` e `lavoro/avvio-con-gioco` sono unite; PR #2 chiusa) |
| Mod nel repo | `v14-bozza-399dcf74` (DEV_MODE false) = v14 + numero iniziale di veicoli |
| PC / gioco (09.10 ~18:30) | mod installata `v14-bozza-32c86032` (senza flotta iniziale); middleware sul PC in `<dati TF3>\local\capocantiere\middleware` aggiornato a main (backup in `capocantiere\backup\middleware_09.10.2026`); Steam avvia la console con il gioco |

### Capacita' verificate in questa sessione (10.10.2026)

- **File locali, sola lettura: OK** tramite PowerShell. Verificate cartelle dati `capocantiere`, `capocantiere/middleware`, `mods/tfcapocantiere_1`, `mod_presets`, `crash_dump`. Scrittura verificata nel checkout E: e nelle fixtures di test autorizzate; nessuna scrittura nei dati del gioco. Mantenere backup e autorizzazioni del progetto.
- **Terminale e Node REPL: ora OK anche nel sandbox ordinario**, riprovati dopo aver liberato spazio, senza cambiare configurazioni. PowerShell 5.1.26100.9444. Il precedente errore MXC non si riproduce nel controllo attuale: non modificare il sandbox preventivamente.
- **Python: OK**, 3.10.10, interprete e launcher `py` funzionanti. Pacchetto `anthropic` presente; `pytest` e `lupa` non rilevati. Nessuna chiave API letta/usata e nessun pacchetto installato.
- **Git locale ora installato e funzionante**, 2.55.0.windows.5, via winget autorizzato. Installato in C:\Program Files\Git; PATH persistente registrato, ma l'app gia' aperta conserva il PATH vecchio: usare percorso completo o aggiunta al PATH della sola sessione, oppure riaprire l'app/terminale. **Unico checkout completo:** `E:\Sviluppo\TF3-capocantiere`, separato dai dati del gioco, main allineato al remoto e pulito dopo clonazione.
- **GitHub: lettura OK**, connettore riporta permesso push; la pubblicazione di questo checkpoint costituisce la prova di scrittura e deve essere riletta dopo il commit. Niente PR e niente force-push.
- **Steam: eseguibile, protocollo steam:// e processo attivi**. Finestra Steam trovata tramite UI Automation fuori sandbox, visibile e abilitata. **TF3: manifest ed eseguibile presenti** in `E:\SteamLibrary`, processo assente. Start-Process disponibile: avvio possibile da preparare, NON eseguito.
- **Installazione effettiva letta:** mod `v14-bozza-32c86032`, `DEV_MODE = true`; avviatore `avvia_capocantiere.bat` ancora 435 byte, coerente col precedente handoff. State.lua residuo: stessa versione, lastActionId 1, speed 0; dato storico a gioco chiuso, NON una misura della partita attuale.
- **Spazio ultimo controllo:** C: 27,28 GB, E: 709,99 GB (decimali). Suite completa nel venv: ultimo giro 37/37 OK, con incidente intermittente Windows descritto sopra. Nessuna chiave API usata, nessuna azione o scrittura nei dati reali del gioco. Il bridge vivo e il mock Lua locale non sono stati eseguiti.

- **Desktop Windows nativo:** screenshot desktop in memoria OK (3440x1440). Ulteriore prova in sola lettura: finestra Steam SDL_app visibile, rettangolo (0,0)-(1720,1392), cattura della sola finestra via PrintWindow OK (1008 colori distinti campionati), senza focus/input e senza salvare immagini. UI Automation vede solo 4 discendenti, zero InvokePattern e nessuna etichetta TF3: non offre pulsanti Steam utilizzabili semanticamente. Per interagire serve controllo guidato dalle immagini + Win32, ancora da collaudare. Processi Steam visibili solo fuori sandbox; TF3 non avviato.
- **Input:** entrypoint Win32 SendInput/SetForegroundWindow/EnumWindows/PostMessageW presenti, ma NESSUN clic, tasto, cambio focus o comando di chiusura provato. PIL presente; pyautogui, pywinauto e mcp non rilevati. Nessun tool computer-use dedicato esposto; due ricerche plugin non hanno trovato un'integrazione pertinente (catalogo non esaustivo). Una piccola interfaccia locale via Win32/UI Automation puo' colmare il divario, ma deve essere implementata/testata prima di dichiarare parita' con Claude.
- **Mock Lua locale:** run_mock.py letto da main carica soltanto /usr/lib/x86_64-linux-gnu/liblua5.*.so*. Non funziona direttamente su Windows; non basta installare lua.exe. Lua standalone non trovato nel PATH. Occorre un runner compatibile Windows + DLL Lua autorizzata, oppure usare la CI Linux dichiarandola CI, non test locale.

### Collaudo grafico Steam autorizzato (10.10.2026)

Finestra identificata per PID, titolo Steam e classe SDL_app; screenshot PrintWindow acquisito/letto localmente. Focus SetForegroundWindow riuscito, GetForegroundWindow conferma il target. Tentativo mouse/tastiera con PostMessageW indirizzato al solo HWND Steam: API accetta ma Steam ignora gli eventi, screenshot invariato e campo ricerca vuoto. Non dichiarare riusciti gli input. Nessun processo TF3 avviato, nessuna modifica ai dati del gioco; immagini solo nell'area work, non pubblicate.
Prossima prova autorizzata: SendInput nativo con controllo HWND/PID/focus e finestra al punto del clic prima di ogni evento, interazione limitata alla ricerca libreria. SendInput e' un'API globale: questi controlli riducono la finestra di rischio ma non costituiscono un confinamento OS; abortire se il focus cambia. Nessun hotkey globale, nessun Invio su un gioco.

### Provato su Windows il 09.10.2026

- Avvio con il gioco (`avvia_con_gioco.bat` nelle Opzioni di avvio di Steam): la console si apre con il gioco, aspetta
  nel menu e scrive "console pronta" quando si carica la mappa con la mod. Da verificare: chiusura con il gioco.
- `avvia_capocantiere.bat` attiva da solo le azioni v14 (`CAPOCANTIERE_BOZZA=1`) se la mod installata e' una "bozza"
  (non ancora provato).

### Unito in main, NON ancora provato su Windows/TF3

- Numero iniziale di veicoli alla creazione delle linee (`CC.estimateFleet`/`CC.initialFleet`, ex branch flotta).
- Middleware: timeout sicuri e risultati tardivi (commit 04).

### Console reale provata (10.10.2026, Claude, aggiornato dopo la prova riuscita)

- Avvio da Steam: OK (console in attesa nel menu, "console pronta" alla mappa). Chiusura con il gioco: non verificata.
- Richiesta 1 "panoramica della mappa": OK, 13'143 token (8'300 di scrittura cache al primo giro).
- Richiesta 2 "linea bus a Lissone": il primo tentativo e' stato rifiutato con "partita in pausa" (state.lua: speed = 0);
  Nicolo' ha poi riavviato e ridato il comando **dalla console aperta con il gioco gia' in movimento: linea costruita e
  collaudo OK** (linea "Lissone Bus" id 74233, 4 fermate, nuovo deposito, 2 eCitaro). Il controllo della pausa quindi
  FUNZIONA quando il gioco scorre; resta da capire perche' il primo tentativo leggeva 0 (gioco forse ancora in pausa
  dopo il caricamento, o velocita' non aggiornata subito). Non e' un errore confermato: solo da osservare.
  Costo: 30'790 token per la sessione con 2 richieste (7 chiamate).
- File gia' pronto ma NON installato sul PC: `middleware/avvia_capocantiere.bat` di main (attiva da solo
  `CAPOCANTIERE_BOZZA=1`): la copia sul PC e' ancora la vecchia (435 byte, nuova 798). Va copiata a gioco chiuso
  (un .bat in esecuzione non si modifica). Attenzione: un commit verso il PC con lo stesso stagedPath di prima ha scritto
  il contenuto vecchio: usare sempre un percorso nuovo e rileggere dal PC.
- Middleware sul PC: `<dati TF3>\local\capocantiere\middleware` (= main, tranne il .bat sopra).

### Piano concreto per parita' operativa con Claude sul PC

Vincoli: installazioni, modifiche ai file del gioco e operazioni rischiose richiedono autorizzazione esplicita in questa chat; backup prima di modificare file esistenti. Nessuna chiave API usata/letta, nessuna costruzione automatica, nessun salvataggio modificato. Pubblicare un handoff dopo ogni passo.

1. **Git e unico checkout: COMPLETATO su autorizzazione di Nicolo'.** Git assente anche dalle chiavi registro GitForWindows controllate. Installazione proposta: `winget install --id Git.Git -e --source winget`, fonte https://git-scm.com/install/windows . Destinazione scelta/autorizzata da Nicolo': `E:\Sviluppo\TF3-capocantiere`, distinta dal middleware installato. Prima ricontrollare che non esista; dopo installazione verificare `git --version`, clonare una sola volta, leggere AGENTS.md se presente, controllare `git status`, origin e head contro main remoto. Non cambiare identita' Git globale senza richiesta.
2. **Test Python completi: ESEGUITI in venv isolato.** Ultimo giro 37/37 OK; primo giro 36 OK e 1 errore Windows di lock riprodotto, da correggere senza cambiare il bridge installato. Preparare esecuzione del mock Windows adattando `dev-notes/bozza/run_mock.py` alla DLL Lua, con dipendenza installata solo dopo autorizzazione. Verificare mock 71 controlli secondo checkpoint storico e `python dev-notes/build_script.py --check --bozza`; distinguere conteggi reali dai titoli obsoleti della CI. Nessuna patch al runner gia' fatta.
3. **Controllo PC nativo, senza nuova dipendenza se sufficiente.** Preparare helper locale proposto `dev-notes/strumenti/windows_pc.py`: screenshot della sola finestra target, elenco/focus di finestre Steam/TF3, avvio Steam e TF3, input limitato alle finestre target. Utilizzare Win32/UI Automation e PIL gia' disponibili; autorizzare le azioni effettive prima delle prove. Primo collaudo: screenshot Steam + selezione target, nessun comando sulla partita. Fare riferimento alle dimensioni reali, non riusare coordinate del vecchio handoff. Verificare chiusura ordinaria, non taskkill forzato.
4. **Bridge vivo senza costruzioni.** Dopo autorizzazione ad avviare/caricare la partita e a scrivere nella cartella `mod_presets`: controllare file azioni residui e stato fresco, poi richiesta ping/lettura con nonce nuovo e risultato corrispondente. Non chiamare main.py/Anthropic. ATTENZIONE: GameBridge.send() pulisce/elimina risultati gia' letti; rispettare il divieto di cancellazione del progetto usando conservazione dei file di prova o autorizzazione esplicita alla sola pulizia dei file generati. Verificare due aggiornamenti dello state, senza confondere file residui con partita attiva.
5. **Allineamento installazione (autorizzazione separata).** A gioco chiuso, backup e confronto impronte prima/dopo: aggiornare il .bat da 435 byte alla copia main, produrre build dev/bozza e installarla solo nelle cartelle ammesse. Rileggere dal PC, verificare versione e DEV_MODE; non modificare installazione Steam, res/scripts o salvataggi. Prima di usare il vecchio avvia_con_gioco.bat considerare che chiude la console con taskkill /t /f: questa chiusura e' ancora non provata e non va lanciata implicitamente dal test.
6. **Collaudo operativo con Nicolo'.** Avvio/caricamento/lettura/uscita, chiusura console con gioco e riavvio dopo crash su test autorizzato (non provocare crash). Solo dopo: terza richiesta v14 e confronto flotta stimata/misurata. Le richieste di costruzione richiedono sua direttiva esplicita. La console Claude resta distinta da Codex: stesso bridge/file/mod e controllo PC possono fornire parita' operativa senza usare la chiave Anthropic.

### Prossima operazione precisa

Il setup autorizzato e' completato: Git installato, unico checkout E:\Sviluppo\TF3-capocantiere pulito/allineato, suite completa eseguita e checkpoint pubblicati.
Proseguire con controllo grafico guidato dalle immagini della sola finestra Steam (UI Automation non espone pulsanti), iniziando con letture/catture senza input. Clic/tastiera e avvio/caricamento/chiusura TF3 restano non collaudati. Concordare le prove effettive sul gioco prima di eseguirle; mod installata, salvataggi e file del gioco NON autorizzati alla modifica.
Problema tecnico da tenere aperto: letture concorrenti Windows possono impedire os.replace dei file Lua; non dichiararlo risolto dal solo giro verde. Mock Lua Linux-only ancora da adattare/installare con autorizzazioni pertinenti.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

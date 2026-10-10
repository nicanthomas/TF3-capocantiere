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

**10.10.2026, Codex locale Windows.** Unico checkout E:\Sviluppo\TF3-capocantiere, main. Git 2.55.0.windows.5, Python 3.10.10, PowerShell funzionanti. Nessuna installazione in questa sessione. Venv stdlib e fixtures nell'area work della chat; rete, subprocess e accessi Steam bloccati durante i test Python. Pubblicazione tramite connettore GitHub con verifica del main remoto, senza PR/force-push.

### Autorizzazioni e blocco TF3

Autorizzati sviluppo sorgenti nel checkout, test, pubblicazione, avvio TF3 via Steam, input nel solo menu e chiusura normale. Vietati caricamenti/salvataggi/costruzioni, modifiche a mod installata o gioco, installazioni, chiave Anthropic e Taskkill/chiusure forzate.
Opzioni Steam lette senza modificarle: avvia_con_gioco.bat con %command%. La copia installata avvia la console che legge la chiave Anthropic e termina la console con taskkill /t /f. TF3 NON avviato: queste opzioni contraddicono i vincoli attuali. File installati e opzioni invariati; nessuna chiave letta/usata. Prova reale menu/focus/input/chiusura TF3 ancora da fare.

### Risultato del passo completato

Lua portabile: dev-notes/lua_runtime.py condiviso da run_mock.py, luachk.py e build_script.py. Ricerca librerie di sistema Linux/macOS; Windows richiede CAPOCANTIERE_LUA_LIB con percorso assoluto di DLL fidata 5.3/5.4 della stessa architettura Python. Nessuna ricerca nei dati del gioco, nessuna installazione. Prototipi ctypes espliciti, stato sempre chiuso anche su errori, controllo sintassi senza esecuzione. Runner importabile senza esecuzione implicita.
Intera suite locale isolata **50/50 OK**, 14,681 s: 37 precedenti, 5 regressioni scritture atomiche, 8 wrapper Lua (ABI simulata, non runtime Lua reale). Mock Windows tentato: errore esplicito libreria mancante, NON eseguiti controlli Lua. build_script.py --check --bozza: sintassi saltata per libreria assente e codice 1, script repo non allineato; e' l'avviso gia' previsto dalla CI, non generata/copiata alcuna mod.
Correzione lock Windows gia' pubblicata: lettore chiuso prima del parsing, sostituzione atomica con massimo 25 pause da 20 ms per WinError 5/32/33; file precedente preservato su errore definitivo. Include test con lock Windows reale. CI ora include job Windows Python oltre a Ubuntu; esiti CI da rileggere dopo pubblicazione.

### Capacita' e prove precedenti da conservare

Steam: PrintWindow e focus/input SendInput provati su ricerca, cancellazione e ripristino; PostMessage ignorato. UI Automation non espone pulsanti. Controlli HWND/PID/titolo/focus e finestra sotto il clic; SendInput globale resta soggetto a race, nessuna garanzia OS di esclusivita'. Processi Steam visibili fuori sandbox. Screenshot solo locali, nessun dato account pubblicato. Procedura dev-notes/note/controllo-grafico-windows.md.
Mod repo v14-bozza-399dcf74 DEV_MODE false; installata v14-bozza-32c86032 DEV_MODE true (lettura precedente), non aggiornata. Console Claude: panoramica e linea Lissone provate da Claude, non ripetute da Codex; numero iniziale flotta non ancora provato in gioco. Il .bat installato e' ancora la versione precedente da 435 byte; non copiarlo senza autorizzazione distinta. Bridge vivo non provato; GameBridge.send elimina risultati letti, incompatibile con divieto di cancellazione senza accordo specifico.

### Prossima operazione precisa

Sviluppare dev-notes/strumenti/windows_pc.py dal probe grafico: identificazione dinamica, verifica identita'/focus esplicita anche con Python -O, screenshot della sola finestra, input limitati e test senza gioco. Verificare CI Ubuntu/Windows del checkpoint; sistemare nota grafica con testo UTF-8 corretto. TF3 resta bloccato dal wrapper installato, da risolvere con autorizzazione distinta prima dell'avvio. Non modificare opzioni/file installati e non usare Taskkill o Anthropic.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

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

Corretto falso verde preesistente del mock Lua: i check falliti ora sollevano errore, runner ritorna1. Regres?sione con Lua REALE in CI Ubuntu e check(false) iniettato soltanto nel testo in memoria. RED run38044823330:71ok/1fallito e AssertionError0!=1. GREEN run38044947518: Ubuntu69 test,1skip Windows,13,937s; mock normale71ok/0falliti. Windows CI verde senza runtime Lua, integrazione dichiarata skip. Ubuntu richiede CAPOCANTIERE_REQUIRE_LUA=1: DLL mancante non puo' nascondere regressioni via skip. Revisione indipendente senza blocchi.
Suite Windows locale isolata **64/64 OK**,14,693s,1skip di classe Lua per DLL assente. Test ABI Lua simulata8, guardie Windows14 anche -O, regressioni lock5 incluso lock Windows reale. Helper Steam provato: screenshot/focus/ricerca/testo/ripristino riusciti,12Backspace totali; frame finale stabile ispezionato. Nessun TF3 avviato, processo assente.
Correzione lock solo sorgenti: parsing dopo chiusura lettore, retry atomico nominale0,5s per WinError5/32/33, vecchio file preservato su errore definitivo. Helper controlla anche pulsanti laterali mouse, drift puntatore e --rect da screenshot recente. SendInput globale resta soggetto a race; niente input concorrente.
Mock Lua Windows reale non eseguito per DLL mancante: libreria fidata5.3/5.4 stessa architettura Python via percorso assoluto, nessuna installazione. build --check --bozza: sintassi locale saltata, confronto DIVERSO/codice1 (anche avviso previsto CI), nessuna mod generata/installata. TF3 bloccato da wrapper installato che legge chiave e usa Taskkill; opzioni/file installati invariati. Nessuna chiave/mod/salvataggio/file gioco usati o modificati.

### Capacita' e prove precedenti da conservare

Steam: PrintWindow e focus/input SendInput provati su ricerca, cancellazione e ripristino; PostMessage ignorato. UI Automation non espone pulsanti. Controlli HWND/PID/titolo/focus e finestra sotto il clic; SendInput globale resta soggetto a race, nessuna garanzia OS di esclusivita'. Processi Steam visibili fuori sandbox. Screenshot solo locali, nessun dato account pubblicato. Procedura dev-notes/note/controllo-grafico-windows.md.
Mod repo v14-bozza-399dcf74 DEV_MODE false; installata v14-bozza-32c86032 DEV_MODE true (lettura precedente), non aggiornata. Console Claude: panoramica e linea Lissone provate da Claude, non ripetute da Codex; numero iniziale flotta non ancora provato in gioco. Il .bat installato e' ancora la versione precedente da 435 byte; non copiarlo senza autorizzazione distinta. Bridge vivo non provato; GameBridge.send elimina risultati letti, incompatibile con divieto di cancellazione senza accordo specifico.

### Prossima operazione precisa

Branch lavoro/flotta-regressioni: RED CI sui dettagli count limitati e fallback delle posizioni mancanti. Nessuna modifica a flotta in gioco o mod installata; main resta al checkpoint verde del mock. Dopo RED correggere soltanto CC.initialFleet, verificare GREEN CI e unire senza PR.

Mock corretto e testato in CI prima dell'unione in main, senza PR/force. Verificare CI nuovo main; proseguire sui casi limite della flotta iniziale (solo sorgenti/mock, nessuna costruzione): dettagli count devono corrispondere al numero effettivamente limitato, posizioni mancanti non devono produrre una stima incompleta. Usare regressioni Lua in CI Ubuntu, dato che Windows manca DLL. Non rigenerare/installare la mod e non avviare TF3 con wrapper attuale. Ancora non provati menu/input/chiusura TF3, bridge vivo e flotta iniziale in gioco.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

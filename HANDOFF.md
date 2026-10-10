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

### Autorizzazioni e stato TF3

10.10.2026, nuova autorizzazione esplicita al ciclo temporaneo delle sole opzioni Steam, backup/ripristino, avvio senza wrapper, menu e uscita normale. NON modificare file wrapper, gioco, mod installata, salvataggi o chiavi; niente installazioni, partite/costruzioni o bridge vivo. Sviluppo sorgenti e test senza gioco autorizzati.
Opzioni ORIGINALI RIPRISTINATE: confronto esatto riuscito dopo chiusura del dialogo, impronta e due copie private integre. TF3 TERMINATO. Backup privati work/steam-launch-options-session2/original.json e recovery-copy.json nella chat; copia recupero privata negli outputs. Nessun valore sensibile pubblicato. Nessuna scrittura diretta al VDF o al wrapper.
Le opzioni originali richiamano ancora avvia_con_gioco.bat e %command%: i futuri avvii senza chiave/Taskkill richiedono di ripetere la procedura temporanea autorizzata, non cliccare Gioca con il wrapper attivo.

### Risultato del passo completato

Tasti Windows completati: Controller.key/Native.key_pair e CLI key --key escape/tab a scancode. Otto regressioni nuove RED poi GREEN; 22/22 controller anche -O, DLL simulate, nessun input desktop nei test. Locale isolato 80 OK/classe Lua skip, 15,770 s. CI GREEN 38048277232: Ubuntu 88 test/1 skip Windows, 14,007 s; Windows 80/1 classe Lua skip, 14,501 s; mock normale 71 ok/0 falliti. RED CI precedente 38048150135. Revisione indipendente senza blocchi; integrazione main dopo confronto remoto. Nuova CLI non rieseguita in TF3 dopo ripristino; codifica Esc osservata nel probe precedente, Tab non provato visibilmente.

Collaudo TF3 reale, build 40420, riuscito in due cicli menu soltanto. Avvio via Steam con opzioni vuote; finestra verificata da percorso exe esatto/PID/HWND/classe/geometria; PrintWindow leggibile e focus verificato. Mouse: icona impostazioni apre il pannello; nessun valore cambiato. Tastiera: Tab e Esc virtual-key con scan=0 accettati da SendInput ma senza effetto visibile; Esc con KEYEVENTF_SCANCODE e scan=0x01 torna al menu, frame stabile ispezionato. Non dichiarare il semplice successo API prova funzionale.
Uscita tramite icona Esci del menu: chiude direttamente senza conferma. Processo TF3 assente in entrambi i cicli; Steam Gioca tornato visibile. Screenshot immediato dopo uscita puo' fallire per finestra scomparsa; Steam puo' mostrare ancora Ferma durante aggiornamento, non premerlo. Nessuna chiave/Taskkill, partita caricata, costruzione, installazione o modifica agente ai file gioco/mod/salvataggi.
Ripristino: nuovo HWND del dialogo Steam identificato prima degli input, opzioni reinserite dal backup senza stamparle, confronto esatto dopo chiusura riuscito. Il ricontrollo post-click puo' segnalare finestra scomparsa quando il clic chiude il dialogo: non e' una prova di input errato; verificare esito e non inviare altri eventi alla cieca. Nota ripristino-opzioni-steam.md e controllo-grafico-windows.md aggiornate.

Sorgenti gia' verificati nella sessione precedente: salvataggio Lua atomico Windows (5 regressioni incluso handle reale), wrapper ctypes (8 ABI), controller 14 anche -O, flotta iniziale (3 regressioni Lua reali), mock fallito ora exit1. Runner isolato stdlib, 8 policy; locale 72 test OK/1 classe Lua skip, CI Ubuntu 80/1 skip e mock normale 71 ok/0 falliti. Main precedente CI 38046662254 verde. DLL Lua Windows fidata assente, nessuna installazione. build --check --bozza resta DIVERSO/avviso, non dichiararlo verde. Mod non rigenerata/installata e flotta non provata in TF3.
Qualita' merci: soli tipi distribuiti letti; campi noti ma unita'/intervalli e comportamento userdata non provati. Nota qualita-merci-tipi-tf3.md e STATO4c.

### Capacita' e prove precedenti da conservare

Steam: PrintWindow e focus/input SendInput provati su ricerca, cancellazione e ripristino; PostMessage ignorato. UI Automation non espone pulsanti. Controlli HWND/PID/titolo/focus e finestra sotto il clic; SendInput globale resta soggetto a race, nessuna garanzia OS di esclusivita'. Processi Steam visibili fuori sandbox. Screenshot solo locali, nessun dato account pubblicato. Procedura dev-notes/note/controllo-grafico-windows.md.
Mod repo v14-bozza-399dcf74 DEV_MODE false; installata v14-bozza-32c86032 DEV_MODE true (lettura precedente), non aggiornata. Console Claude: panoramica e linea Lissone provate da Claude, non ripetute da Codex; numero iniziale flotta non ancora provato in gioco. Il .bat installato e' ancora la versione precedente da 435 byte; non copiarlo senza autorizzazione distinta. Bridge vivo non provato; GameBridge.send elimina risultati letti, incompatibile con divieto di cancellazione senza accordo specifico.

### Prossima operazione precisa

Collaudo menu completato, gioco chiuso e opzioni originali ripristinate; tasti Windows verificati/uniti. Passo attivo lavoro/qualita-merci da questo main, unico checkout: aggiungere CC.normalizeCargoQuality(summary) e CC.lineCargoQuality(line_id) in b8; dato passengers/cargo distinto con available/errors, campi dichiarati copiati per accessi espliciti pcall, nessuna enumerazione o messaggio eccezione raw. Collegare out.cargo_quality in b2 solo quando apply non e' true, anche se tempi giro mancanti. Guasti API non cambiano ok/stima/proposta flotta e non inviano comandi. Test mock RED in CI prima del codice e un test Lua userdata sintetico; nessuna prova C++ TF3. Prossimo passo sui sorgenti: normalizzazione qualita' merci in b8 e regressioni mock prima dell'integrazione di lettura in check_line_fleet (alias middleware di adjust_line_fleet apply=false). Leggere solo campi dichiarati, pcall sugli accessi userdata, separare passengers/cargo, preservare nil/false/zero e numero averageQuality senza inventare unita'/range. Rifiutare numeri non finiti o tipi inattesi nel risultato serializzabile. Rapporto bad_fraction solo con contatori validi e denominatore positivo; zero non diventa falso dato. Nessuna chiamata di modifica gioco, nessuna installazione. DLL Windows assente: mock reale in CI Ubuntu obbligatorio. Bridge vivo, userdata C++ qualita' merci e flotta in partita NON provati. Unico checkout, niente PR/force-push.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

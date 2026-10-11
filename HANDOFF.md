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

**11.10.2026, Codex locale Windows, ripresa autorizzata da continua.** Unico checkout E:\Sviluppo\TF3-capocantiere, main. Git 2.55.0.windows.5, Python 3.10.10, terminale PowerShell 7.6.5 funzionanti. Nessuna installazione in questa sessione. Venv stdlib e fixtures nell'area work della chat; rete, subprocess e accessi Steam bloccati durante i test Python. Pubblicazione tramite connettore GitHub con verifica del main remoto, senza PR/force-push.

### Autorizzazioni e stato TF3

10.10.2026, nuova autorizzazione esplicita al ciclo temporaneo delle sole opzioni Steam, backup/ripristino, avvio senza wrapper, menu e uscita normale. NON modificare file wrapper, gioco, mod installata, salvataggi o chiavi; niente installazioni, partite/costruzioni o bridge vivo. Sviluppo sorgenti e test senza gioco autorizzati.
Opzioni ORIGINALI RIPRISTINATE: confronto esatto riuscito dopo chiusura del dialogo, impronta e due copie private integre. TF3 TERMINATO. Backup privati work/steam-launch-options-session2/original.json e recovery-copy.json nella chat; copia recupero privata negli outputs. Nessun valore sensibile pubblicato. Nessuna scrittura diretta al VDF o al wrapper.
Le opzioni originali richiamano ancora avvia_con_gioco.bat e %command%: i futuri avvii senza chiave/Taskkill richiedono di ripetere la procedura temporanea autorizzata, non cliccare Gioca con il wrapper attivo.

### Continuazione autonoma richiesta da Nicolo'

Checkpoint frequenti e pubblicazione prima di fermarsi; interruzione crediti non prevedibile. Parser completo gia' verificato/integrato, RED 38137476301 e GREEN 38137669139, locale 97 OK/classe Lua skip, revisione senza blocchi; nota parser-lua-completo.md.

Sonda snapshot completata: tool standalone stdlib+parser, input assoluto esplicito/nome stato, rifiuto UNC sintattico/symlink file, regularfile/8 MiB/read bounded/firme prima-dopo. JSON solo conteggi/validita'/errori fissi; no nomi/coordinate/path raw, game_bridge/ambiente/ricerca/DLL o scritture. Sette regressioni RED locale/CI 38138031056 prima del codice; GREEN 38138252617 Ubuntu 118/1 skip Windows, 14,292 s; Windows 104/classe Lua skip, 14,549 s; mock 104/0. Locale 104 OK/classe Lua skip, 16,401 s. CLI normale/-O solofixture exit0, live_bridge_tested=false. Revisione senza blocchi, limite volume/junction recepito: localita' fisica e atomicita' OS NON certificate. Mai eseguita sui dati reali. Nota sonda-bridge-lettura.md.

Parser numeri/separatori completato: cinque regressioni RED locale 109/11 fallimenti/3 errori e CI 38138543778 prima del codice. Interi decimali senza float intermedio, esponenti finiti, meno separato numerico e separatori table richiesti. GREEN 38138777270 Ubuntu 123/1 skip Windows, 14,008 s; Windows 109/classe Lua skip, 14,385 s; locale 109 OK/classe Lua skip, 16,283 s. Revisione senza blocchi. Nota parser-lua-numeri.md. Nessun runtime Lua/chiave/dati reali.

Parser Unicode completato: testo letterale preservato, buffer soltanto escape numerici UTF-8/fallback Latin-1 per run, byte 0..255 e hex2 cifre. Rilievo revisione z risolto con settima regressione RED 38139382189 prima fix; locale finale 116 OK/classe Lua skip, 16,254 s; GREEN finale 38139535647 Ubuntu 130/1 skip Windows, 14,803 s; Windows 116/classe Lua skip, 14,494 s; mock 104/0, revisione approvata. Nota parser-lua-unicode.md: subset testuale, non API byte o grammatica Lua generale. Mai file reali.

Passo attivo lavoro/screenshot-gdi: tre regressioni API simulate prima codice, riproduzione restituisce BMP/leak nel modello se ripristino fallisce. Design verifica deselect prima GetDIBits e cleanup DeleteDC memoria prima DeleteObject; nessuna API reale/input. Backup privato, nota screenshot-gdi-risorse.md. RED locale 119 test/3 fallimenti/1 classe Lua skip, 16,324 s, coerenti con riproduzione; sorgente capture invariato. CI RED prima fix.

### Risultati verificati della ripresa 11.10.2026

Cinque passi sorgenti/test completati e integrati, senza nuove operazioni Steam o TF3:

- Indicatori industrie: tre booleani protetti, false distinto da assenza, productivity nelle industrie posizionate di read_map; API assente/guasta preserva mappa/ok, nessun comando. Dodici mock e un userdata Lua sintetico, RED prima del codice. GREEN 38134484171 (Ubuntu 94 test, Windows 80, mock 104/0). Nota produttivita-industrie.md. C++ TF3/significato boost NON provati.
- Barriera Lua: export lua_isinteger richiesto prima dello stato, standard 5.2 respinto; una regressione ABI simulata RED poi GREEN 38134989337 (Ubuntu 95, Windows 81, mock 104/0). Locale 81 OK/classe Lua skip. Non certifica versione esatta/provenienza/architettura/DLL custom; nessuna Lua 5.2 reale caricata. Nota abi-lua-versioni.md.
- Diagnosi PE: nove regressioni sintetiche RED poi GREEN 38135628133 (Ubuntu 104, Windows 90, mock 104/0); locale 90 OK/classe Lua skip, 16,114 s; revisione senza blocchi. Tool stdlib solo header bounded Python/candidato esplicito; I386/AMD64/ARM64 distinti anche stessa bitness, nessuna ricerca/ambiente/LoadLibrary/scrittura. Prova Python reale senza candidato: AMD64 64 bit, errors=[], runtime_loaded=false. JSON privato negli outputs. Nessuna DLL candidata reale ispezionata. Nota diagnosi-lua-windows.md: NON certifica DLL, export, versione, dipendenze o fiducia.
- Descrizioni Python: read_map/check_line_fleet e prompt bozza allineati ai dati facoltativi; available/errors per ramo, false/zero distinti da assenza, niente moltiplicatori/unita'/automazioni inventati. Schemi/routing/conferme/Lua invariati. Locale isolato 90 test OK/classe Lua skip, 16,120 s; GREEN 38136433834 Ubuntu 104 test/1 skip Windows, 14,154 s; Windows 90/classe Lua skip, 14,162 s; mock normale 104/0. Revisione statica senza problemi, nessuna chiamata al modello/vecchia mod. Nota descrizioni-dati-bozza.md.

- Runner Lua obbligatoria: --require-lua opt-in, default skip conservato, JSON lua_required; tre regressioni bootstrap policy reale/loader simulato RED 38136828824 prima del codice. GREEN 38136991438 Ubuntu 107 test/1 skip Windows, 13,974 s; Windows 93/classe Lua skip, 15,003 s; mock 104/0. Locale default 93 OK/classe Lua skip, 16,212 s. Prova opt-in reale senza runtime exit1 atteso, 93 test/1 LuaUnavailable/zero skip, 16,111 s: nessuna DLL caricata. Revisione senza blocchi; guardie/isolamento invariati. Nota lua-obbligatoria-isolata.md.

DLL Lua Windows fidata ancora assente: la classe nativa locale e Windows CI e' SKIP, non una prova superata; Lua reale obbligatoria in Ubuntu CI. build --check --bozza ancora DIVERSO/avviso, non dichiarare verde o rigenerare/installare senza nuova autorizzazione.

### Collaudo TF3 e sorgenti precedenti (10.10.2026)

TF3 build 40420, due cicli soltanto menu con wrapper temporaneamente disattivato nelle opzioni. Finestra identificata da exe/PID/HWND/classe/geometria, PrintWindow e focus verificati. Mouse apre impostazioni senza cambiamenti; Esc fisico scan=0x01 ritorna al menu. Virtual-key scan=0 accettato ma senza effetto visibile; Tab fisico NON provato. Uscita normale tramite icona Esci senza conferma, processo terminato, Steam Gioca tornato visibile. Nuovo HWND Steam identificato per ripristino; confronto esatto opzioni dopo chiusura riuscito, due backup privati integri. Nessuna chiave/Taskkill/partita/costruzione. Note controllo-grafico-windows.md e ripristino-opzioni-steam.md. Non ripetuto nella ripresa 11 ottobre.

Sorgenti gia' verificati: lock Lua Windows (cinque regressioni, anche handle Windows reale), wrapper ctypes, guardie controller e tasti escape/tab a scancode, cargo_quality, limiti flotta e tempi finiti/overflow intero. RED/GREEN e revisione conservati nei commit precedenti e nelle note STATO.md, qualita-merci-tipi-tf3.md, flotta-tempi-finiti.md e controllo-grafico-windows.md; regressioni lock in middleware/test_lua_atomic.py. Checkpoint precedente 50949c5, CI 38050518737 Ubuntu 93/1 skip Windows, Windows 80/classe Lua skip, mock normale 92/0. Adattatori userdata sintetici non dimostrano C++ TF3; apply=true solo fixture intercettate, niente azioni reali.

### Capacita' e prove precedenti da conservare

Steam: PrintWindow e focus/input SendInput provati su ricerca, cancellazione e ripristino; PostMessage ignorato. UI Automation non espone pulsanti. Controlli HWND/PID/titolo/focus e finestra sotto il clic; SendInput globale resta soggetto a race, nessuna garanzia OS di esclusivita'. Processi Steam visibili fuori sandbox. Screenshot solo locali, nessun dato account pubblicato. Procedura dev-notes/note/controllo-grafico-windows.md.
Mod repo v14-bozza-399dcf74 DEV_MODE false; installata v14-bozza-32c86032 DEV_MODE true (lettura precedente), non aggiornata. Console Claude: panoramica e linea Lissone provate da Claude, non ripetute da Codex; numero iniziale flotta non ancora provato in gioco. Il .bat installato e' ancora la versione precedente da 435 byte; non copiarlo senza autorizzazione distinta. Bridge vivo non provato; GameBridge.send elimina risultati letti, incompatibile con divieto di cancellazione senza accordo specifico.

### Prossima operazione precisa

Prossimo passo sicuro: screenshot GDI Windows. Riproduzione con backend completamente simulato: se SelectObject di ripristino fallisce, capture procede a GetDIBits e DeleteObject prima DeleteDC lascia bitmap allocata. Prima regressioni RED/pubblicazione, poi verifica ripristino e ordine cleanup; usare soltanto mock finche' CI/revisione verdi. Successiva eventuale prova screenshot Steam soltanto lettura, senza focus/input o avvio TF3. Sonda snapshot NON usare su dati reali senza ambito concordato, percorso/volume da verificare; evitare GameBridge.__init__/send/cleanup. DLL Lua Windows fidata ancora assente: niente installazione senza autorizzazione distinta. TF3 chiuso, opzioni originali ripristinate nel collaudo precedente, wrapper attivo.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

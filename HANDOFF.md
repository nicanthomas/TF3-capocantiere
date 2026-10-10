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

**Stato:** 10.10.2026 (ChatGPT/Codex locale Windows). Verifica iniziale non distruttiva completata; sviluppo e installazioni non iniziati: C: riporta 0 byte liberi. Nessun file locale modificato dall'agente, nessun salvataggio letto/modificato e nessuna azione inviata al gioco.
Head remoto verificato prima del checkpoint: `19ee5c8fe66416fa50c5cd17eb7fc713ce6d05dd` (10.10.2026-02). Il commit 02 corregge il checkpoint 01: la pausa NON e' un bug confermato. CI di questo head: successo, run `38032270281`; nessun test locale del progetto eseguito in questa sessione. Risultati storici dopo i merge, riportati da Claude: middleware 37 OK, mock 71 OK, `build_script.py --check --bozza` OK.

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | ChatGPT / Codex desktop, controlli locali Windows |
| Branch | solo `main` (le branch `lavoro/flotta-iniziale` e `lavoro/avvio-con-gioco` sono unite; PR #2 chiusa) |
| Mod nel repo | `v14-bozza-399dcf74` (DEV_MODE false) = v14 + numero iniziale di veicoli |
| PC / gioco (09.10 ~18:30) | mod installata `v14-bozza-32c86032` (senza flotta iniziale); middleware sul PC in `<dati TF3>\local\capocantiere\middleware` aggiornato a main (backup in `capocantiere\backup\middleware_09.10.2026`); Steam avvia la console con il gioco |

### Capacita' verificate in questa sessione (10.10.2026)

- **File locali, sola lettura: OK** tramite PowerShell con esecuzione fuori sandbox approvata dal controllo automatico. Verificate cartelle dati `capocantiere`, `capocantiere/middleware`, `mods/tfcapocantiere_1`, `mod_presets`, `crash_dump`. Scrittura locale NON provata: C: pieno; mantenere backup e autorizzazioni del progetto.
- **Terminale: OK fuori sandbox**. Terminale ordinario nel sandbox: KO, `MXC launcher: native MXC is unavailable on this Windows build`. Anche Node REPL KO, con errore MXC e spazio disco insufficiente (os error 112). Non confondere il blocco del sandbox con assenza di accesso al PC.
- **Python: OK**, 3.10.10, interprete e launcher `py` funzionanti. Pacchetto `anthropic` presente; `pytest` e `lupa` non rilevati. Nessuna chiave API letta/usata e nessun pacchetto installato.
- **Git locale: non disponibile nei controlli effettuati**, assente dal PATH e dai percorsi standard di sistema/utente, Scoop e Chocolatey. Nessun checkout trovato nella cartella della chat, sotto Documents/Codex, o nella ricerca dei file HANDOFF.md in Documents/Desktop/Downloads. Una copia altrove non e' esclusa.
- **GitHub: lettura OK**, connettore riporta permesso push; la pubblicazione di questo checkpoint costituisce la prova di scrittura e deve essere riletta dopo il commit. Niente PR e niente force-push.
- **Steam: eseguibile presente e processo attivo**. **TF3: manifest ed eseguibile presenti** nella libreria `E:\\SteamLibrary`, ma nessun processo `transportfever3` rilevato. Controllo grafico/clic non disponibile fra gli strumenti esposti: avvio, caricamento e chiusura del gioco NON provati.
- **Installazione effettiva letta:** mod `v14-bozza-32c86032`, `DEV_MODE = true`; avviatore `avvia_capocantiere.bat` ancora 435 byte, coerente col precedente handoff. State.lua residuo: stessa versione, lastActionId 1, speed 0; dato storico a gioco chiuso, NON una misura della partita attuale.
- **Blocco principale: C: = 0 byte liberi**, confermato due volte; E: ha circa 710 GB liberi al controllo. Nessuna cancellazione, spostamento, installazione o modifica alla configurazione eseguita.

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

### Prossima operazione precisa

1. Ripristinare spazio su C: con intervento esplicitamente autorizzato da Nicolo', senza cancellazioni automatiche. Ripetere il controllo spazio prima di qualunque backup/scrittura nei dati del gioco.
2. Ripristinare il sandbox Windows: l'errore MXC e' distinto dal disco pieno. Le indicazioni ufficiali prevedono `elevated` come fallback quando MXC non e' disponibile; non cambiare configurazioni o installazioni senza autorizzazione. Fonte: https://learn.chatgpt.com/docs/windows/windows-sandbox .
3. Individuare un Git gia' presente oppure configurare Git per Windows e un checkout locale in una cartella scelta/autorizzata; lo sviluppo e' stato richiesto sul PC, non sostituirlo con sviluppo remoto. Verificare stato locale, regole AGENTS.md e head remoto prima di modificare.
4. A gioco chiuso e con spazio sufficiente: backup, copia di `middleware/avvia_capocantiere.bat` da main, rilettura e confronto. Poi build `--dev --bozza` (flotta iniziale), backup/installazione/rilettura secondo i permessi del progetto. Non usare la chiave API dell'utente.
5. Prove reali ancora da fare: chiusura console con il gioco, terza richiesta v14 con costo, confronto flotta stimata/misurata con `check_line_fleet`, timeout/risultati tardivi. Nessuna di queste verifiche e' stata eseguita in questa sessione. Messaggio della pausa facoltativo; non rimuovere protezioni sulla base del checkpoint 01 superato.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

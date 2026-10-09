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
- Il merge e i commit delle attività richieste possono essere effettuati direttamente, quando non comportano decisioni rischiose non autorizzate. Rispettare formato commit, verifiche e vincoli esistenti; non unire codice instabile a `main` solo per creare un checkpoint: usare branch e commit di lavoro dichiarati.
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

**Stato:** inizializzazione del workflow condiviso, 09.10.2026. **Nessuna nuova prova nel gioco effettuata per predisporre questo workflow.** Le attività di sviluppo e i test di gioco più recenti sono descritti in `STATO.md`; verificare commit più nuovi prima di proseguire.

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato il workflow | ChatGPT |
| Ultimo aggiornamento | 09.10.2026, Europe/Zurich (configurazione workflow) |
| Branch di riferimento | `main` |
| Commit base noto prima di questo aggiornamento | `538957c34e9afeb3e85475444b73575cf7ed8afd` |
| Commit finale del checkpoint | Controllare `main` su GitHub: il commit che aggiorna questa riga non può includere il proprio SHA in modo affidabile |
| Obiettivo corrente | Rendere il lavoro riprendibile da una chat vuota, senza intervento manuale sui passaggi |
| Ultimo passo completato | Preparazione delle regole condivise e del prompt di avvio |
| Accessi | GitHub: verificato nella sessione di preparazione; PC/TF3: **non verificati** |
| Modifiche locali non pubblicate | **Sconosciute** per le altre postazioni e AI: non inferire mai «nessuna» dal solo GitHub |

### Lavoro completato e file modificati

- Workflow condiviso: `HANDOFF.md`, `dev-notes/note/STATO.md` e `README.md` (documentazione, nessun codice di gioco cambiato).
- Da rileggere: `dev-notes/note/STATO.md` (situazione della v14, collaudi reali e lavoro ancora da fare).

### Verifiche documentate in questa attività

| Verifica | Ambiente | Esito |
| --- | --- | --- |
| Lettura dei documenti esistenti su GitHub | Repository | Eseguita |
| Verifica pubblicazione delle modifiche | GitHub | Da attestare dal commit/branch corrente |
| Test Python / mock Lua | Non eseguiti per questa modifica solo documentale | Non eseguiti |
| Transport Fever 3 reale | Nessun accesso al gioco utilizzato | Non eseguito |

### Problemi aperti / rischi

- La documentazione tecnica può evolvere mentre un'AI è disconnessa: verificare sempre HEAD prima di scrivere.
- Senza accesso al PC non si possono certificare prove in TF3.
- Se crediti o sessione terminano prima della pubblicazione, il checkpoint può essere incompleto.

### Prossima operazione precisa

1. Verificare il commit HEAD remoto e leggere le parti aggiornate di `dev-notes/note/STATO.md`, soprattutto «Da fare», «Stato del gioco» e «Cause di crash».
2. Verificare se la v14 con la **console Claude reale** sia già stata provata dopo l'ultimo checkpoint documentato. Non ripetere prove già dimostrate.
3. Se il gioco e i permessi sono disponibili, continuare con la prossima prova concreta indicata da `STATO.md`; altrimenti dedicarsi alla robustezza del middleware (timeout, gestione dello stato, idempotenza delle richieste), con test senza gioco.
4. Aggiornare questa sezione con risultati effettivi **prima del passo successivo**.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

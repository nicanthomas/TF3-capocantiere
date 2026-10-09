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

**Stato:** robustezza del middleware ai timeout completata e pubblicata (solo test automatici). **Nessuna prova in TF3 in questa sessione.**

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | Claude (Cowork) |
| Ultimo aggiornamento | 09.10.2026, Europe/Zurich |
| Branch di riferimento | `main` |
| Commit base prima di questo aggiornamento | `1055c6f` (09.10.2026-03-Workflow multi AI chat nuove) |
| Commit finale del checkpoint | Controllare `main` su GitHub (commit `09.10.2026-04-...`) |
| Obiettivo corrente | Middleware robusto senza gioco, in attesa della prova della console Claude reale con Nicolo' |
| Ultimo passo completato | Timeout sicuri in `GameBridge.send` + risultati tardivi (vedi STATO.md punto 5a) |
| Accessi in questa sessione | GitHub: lettura via clone, scrittura via Composio. PC: desktop collegato ma **nessuna cartella e nessun controllo del computer richiesti** (non necessari per questo passo). TF3: non usato |
| Modifiche locali non pubblicate | Nessuna da parte di questa sessione Claude dopo il commit 04 |

### Lavoro completato e file modificati

- `middleware/game_bridge.py`: `GameTimeout` (`status` = `ritirata` / `accettata`), ritiro in `vecchi` dei file azioni non presi dalla mod (al timeout e prima di riusare lo stesso id), `late` + `take_late_results()`, `_cleanup` non cancella i risultati tardivi.
- `middleware/main.py`: `request_status` nel risultato per Claude, `deliver_late_results()` a ogni turno (registro + diario + collaudo).
- `middleware/test_middleware.py`: 3 test nuovi (timeout ritirato, file vecchio con lo stesso id, risultato tardivo + diario). Totale 33.
- `dev-notes/note/STATO.md`: punto 5a.

### Verifiche

| Verifica | Ambiente | Esito |
| --- | --- | --- |
| `python middleware/test_middleware.py` | cloud, senza gioco | 33 OK |
| `python dev-notes/bozza/run_mock.py` | cloud, mock Lua | 65 OK |
| CI GitHub Actions | GitHub | controllare l'esito del commit 04 |
| Transport Fever 3 reale | — | **Non eseguito** |

### Problemi aperti / rischi

- Il nome del passo CI dice ancora «(30)» in `.github/workflows/test.yml` (solo etichetta; non modificato per non toccare i workflow).
- Ritiro al timeout: piccola finestra di gara se la mod prende il file proprio mentre viene spostato; coperta dal ricontrollo dopo 2 s (`WITHDRAW_RECHECK`), da verificare in gioco.
- Console Claude reale (chiave API di Nicolo') e costo per sessione: ancora **non verificati** (STATO.md punto 5).

### Prossima operazione precisa

1. Con Nicolo' presente: prova della console reale (STATO.md punto 5): `git pull` sul PC, partita «capocantiere v14 prova», `set CAPOCANTIERE_BOZZA=1`, `middleware\avvia_capocantiere.bat`, 3 richieste (lettura, `check_line_fleet`, piccola costruzione), annotare i token. Facoltativo: mettere il gioco nel menu durante una richiesta per vedere il messaggio «RITIRATA».
2. Senza gioco: numero iniziale di veicoli calcolato alla creazione delle linee (STATO.md 4b «Da fare»), prima nella bozza `b2`/`b7` e nel mock (`run_mock.py`), poi test.
3. Aggiornare questa sezione prima del passo successivo.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

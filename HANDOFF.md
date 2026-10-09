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

**Stato:** due passi senza gioco completati il 09.10.2026 (Claude). **Nessuna prova in TF3 in questa sessione.**

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | Claude (Cowork) |
| Ultimo aggiornamento | 09.10.2026, Europe/Zurich |
| Branch | `main` (stabile) + `lavoro/flotta-iniziale` (codice non provato in gioco) |
| Commit noti | main `1813592` (04, timeout sicuri, CI verde); branch `2430411` (05.1, flotta iniziale); questo handoff = 05.2 su main |
| Obiettivo corrente | Middleware/bozza pronti per la prova reale con Nicolo' |
| Accessi in questa sessione | GitHub: clone + scrittura via Composio. PC: desktop collegato ma **nessuna cartella e nessun controllo del computer richiesti**. TF3: non usato |
| Modifiche locali non pubblicate | Nessuna da parte di questa sessione Claude |

### Lavoro completato

1. **main, commit 04** — `middleware/game_bridge.py` + `main.py`: timeout sicuri (`GameTimeout` `ritirata`/`accettata`), ritiro dei file azioni non presi dalla mod, risultati tardivi consegnati e registrati nel diario. STATO.md punto 5a. Test 33 OK, CI verde.
2. **branch `lavoro/flotta-iniziale`, commit 05.1** — numero iniziale di veicoli stimato alla creazione delle linee (`CC.estimateFleet`/`CC.initialFleet` in `b2`, usati in b2/b4/b7; treni max 2 senza numero esplicito); `tools_bozza.py` senza default su `num_vehicles`/`count`; `mod/` ricostruita con `--bozza` (`v14-bozza-399dcf74`, DEV_MODE false). Mock 71 OK, test 33 OK. Dettagli in STATO.md della branch (punto 4b).

### Verifiche

| Verifica | Ambiente | Esito |
| --- | --- | --- |
| `middleware/test_middleware.py` | cloud | 33 OK (main e branch) |
| `dev-notes/bozza/run_mock.py` | cloud, mock Lua | main 65 OK; branch 71 OK |
| `build_script.py --check --bozza`, `luachk.py` | cloud | branch: allineato, sintassi OK |
| CI GitHub Actions | GitHub | commit 04: success |
| Transport Fever 3 reale | — | **Non eseguito** |

### Problemi aperti / rischi

- La branch NON va unita a `main` prima della prova in gioco: `metadata.<tipo>Vehicle.topSpeed` (m/s in TF2) e' da verificare in TF3; se manca la stima usa `CC.FLEET_SPEED`.
- La v14 installata sul PC e' `32c86032` (= `main`): la branch richiede una nuova installazione (`build_script.py --dev --bozza`, backup prima, rilettura sha1 dal PC).
- Console Claude reale e costo per sessione: ancora **non verificati** (STATO.md punto 5).
- Etichetta «(30)» nel passo CI di `.github/workflows/test.yml`: solo nome, non modificata.

### Prossima operazione precisa

1. Con Nicolo' presente (serve lui per chiave API e permessi PC): prova della console reale su `main` (STATO.md punto 5), annotare i token.
2. Poi, sulla partita «capocantiere v14 prova»: installare la build `--dev --bozza` della branch, una linea bus tra due citta' SENZA `num_vehicles` -> leggere `fleet` nel risultato; far correre il gioco un giro e lanciare `check_line_fleet`: confrontare stima e misura, correggere `CC.FLEET_*`. Se ok: merge della branch in `main` + CI.
3. Senza gioco, se Nicolo' non c'e': idee piccole da STATO.md 5b (solo lettura/proposte, es. rapporto «stato delle citta'» nel middleware) oppure aggiornare l'etichetta CI.
4. Aggiornare questa sezione prima del passo successivo.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

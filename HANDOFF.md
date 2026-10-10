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

**Stato:** 09.10.2026 sera (Claude). Tutto unito in `main` (regola nuova: niente pull request, merge fatto dall'AI).
Test automatici su `main` dopo i merge: middleware 37 OK, mock 71 OK, `build_script.py --check --bozza` OK.

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | Claude (Cowork) |
| Branch | solo `main` (le branch `lavoro/flotta-iniziale` e `lavoro/avvio-con-gioco` sono unite; PR #2 chiusa) |
| Mod nel repo | `v14-bozza-399dcf74` (DEV_MODE false) = v14 + numero iniziale di veicoli |
| PC / gioco (09.10 ~18:30) | mod installata `v14-bozza-32c86032` (senza flotta iniziale); middleware sul PC in `<dati TF3>\local\capocantiere\middleware` aggiornato a main (backup in `capocantiere\backup\middleware_09.10.2026`); Steam avvia la console con il gioco |

### Provato su Windows il 09.10.2026

- Avvio con il gioco (`avvia_con_gioco.bat` nelle Opzioni di avvio di Steam): la console si apre con il gioco, aspetta
  nel menu e scrive "console pronta" quando si carica la mappa con la mod. Da verificare: chiusura con il gioco.
- `avvia_capocantiere.bat` attiva da solo le azioni v14 (`CAPOCANTIERE_BOZZA=1`) se la mod installata e' una "bozza"
  (non ancora provato).

### Unito in main, NON ancora provato su Windows/TF3

- Numero iniziale di veicoli alla creazione delle linee (`CC.estimateFleet`/`CC.initialFleet`, ex branch flotta).
- Middleware: timeout sicuri e risultati tardivi (commit 04).

### Console reale provata (10.10.2026, Claude, crediti finiti a meta')

- Avvio da Steam: OK (console in attesa nel menu, "console pronta" alla mappa). Chiusura con il gioco: non verificata.
- Richiesta 1 "panoramica della mappa": OK, 13'143 token (8'300 di scrittura cache al primo giro).
- Richiesta 2 "linea bus a Lissone": **BLOCCATA da un falso "partita in pausa"**. `main.py` (`run_game_tool`) rifiuta se
  `state.speed == 0`; la mod (lato GUI, `buildState`) esporta `speed` da `GAME_SPEED.speedup`, che vale **0 anche con
  il gioco che scorre** (state.lua fresco: speed = 0, gameTime 6010800 alle 08:44:46 UTC). Nessuna azione e' stata
  inviata al gioco (lastActionId 0). Sessione: 21'148 token dopo 2 richieste.
  **Correzione da fare**: in `main.py` non fidarsi di `speed` (togliere il blocco o usarlo solo se `gameTime` non avanza
  tra due state.lua); stessa cosa per `main.py` riga ~257 e per l'avviso `CC.gameSpeed()==0` della mod. Verificare in
  gioco quale campo di `GAME_SPEED` dice davvero la pausa (sonda lua_eval con la build dev). Test + push + copiare
  `main.py` sul PC.
- File gia' pronto ma NON installato sul PC: `middleware/avvia_capocantiere.bat` di main (attiva da solo
  `CAPOCANTIERE_BOZZA=1`): la copia sul PC e' ancora la vecchia (435 byte, nuova 798). Va copiata a gioco chiuso
  (un .bat in esecuzione non si modifica). Attenzione: un commit verso il PC con lo stesso stagedPath di prima ha scritto
  il contenuto vecchio: usare sempre un percorso nuovo e rileggere dal PC.
- Middleware sul PC: `<dati TF3>\local\capocantiere\middleware` (= main, tranne il .bat sopra).

### Prossima operazione precisa

1. Correggere il falso "in pausa" (sopra), test, push su main, copiare `main.py` sul PC (backup, rilettura).
2. A gioco chiuso: copiare `avvia_capocantiere.bat`; riprovare "fammi una linea bus a Lissone" e una 3a richiesta;
   annotare costo della sessione.
3. Installare la build `--dev --bozza` di main (399dcf74, flotta iniziale) sul PC; confrontare flotta stimata con
   `check_line_fleet`.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

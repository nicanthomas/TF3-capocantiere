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
2. Leggere per intero `HANDOFF.md` (soprattutto la sezione indirizzata a te: Claude legge «Istruzioni handoff per Claude», ChatGPT legge «Istruzioni handoff per ChatGPT»), poi le regole e le sezioni pertinenti di `dev-notes/note/STATO.md`; quindi i file di codice e le note citati dalla prossima attività.
3. Confrontare il checkpoint con gli ultimi commit; se è obsoleto, ricostruire gli aggiornamenti dai commit senza sovrascrivere modifiche recenti.
4. Verificare i propri accessi reali. In assenza di PC, proseguire con revisione codice, sviluppo e test eseguibili senza gioco; rimandare le verifiche TF3 dichiarandole non eseguite.
5. **Chiedere SUBITO a Nicolo' tutte le autorizzazioni che servono (regola di Nicolo', 12.10.2026).** Leggere la
   prossima operazione e, prima di iniziare, mandare **un solo messaggio** con l'elenco completo di cio' che serve per
   portarla a termine, anche le prove nel gioco, per esempio: accesso al PC e alle cartelle; avviare e chiudere TF3;
   caricare una partita e costruire; installare o aggiornare la mod e il middleware sul PC (con backup); usare la
   console con la chiave API; cambiare le opzioni di avvio di Steam. Per ogni voce dire in una riga a cosa serve.
   Nicolo' risponde una volta sola (si' a tutto, oppure quali voci no). **Mai saltare in silenzio una prova in gioco
   o un'installazione perche' manca un'autorizzazione mai chiesta**: se serve, si chiede. Se Nicolo' e' assente, non
   aspettare bloccati: fare il lavoro possibile e mettere la richiesta al punto 5 della propria sezione di handoff.
   Un'autorizzazione vale per la chat in cui e' data; nella sezione di handoff scrivere quali sono state date.
6. Riprendere **autonomamente** dalla prossima operazione concreta riportata sotto. Se manca una priorità utilizzabile, scegliere il più piccolo passo utile e sicuro da `STATO.md`, senza chiedere a Nicolo' di ricostruire il contesto.
7. Aggiornare e pubblicare questo handoff **durante** il lavoro dopo ogni passo significativo. Non attendere un messaggio di cambio AI.


## Come si scrivono le note di passaggio (vale per entrambe le AI)

Claude e ChatGPT si passano il lavoro **solo attraverso questo file**. Ognuna scrive nella sezione indirizzata all'altra:

- **Claude scrive** in «Istruzioni handoff per ChatGPT».
- **ChatGPT scrive** in «Istruzioni handoff per Claude».
- La propria sezione si **sostituisce per intero** a ogni aggiornamento (niente diario: la storia sta nei commit).
  La sezione dell'altra AI non si modifica, tranne la riga `Letto da ...` in fondo.

Regole di scrittura, perche' l'altra AI capisca al primo colpo:

1. Italiano semplice, frasi brevi. Niente sigle interne o gergo non spiegato (RED/GREEN, numeri di run della CI,
   conteggi di test, nomi di sonde): bastano «test automatici verdi» o «test rotto: nome_del_test».
2. Al massimo **40 righe** per sezione. I dettagli tecnici vanno in `dev-notes/note/...`, qui solo il link.
3. Ogni cosa fatta dice **come e' stata provata**: `PROVATO IN TF3`, `PROVATO SUL PC (fuori dal gioco)` oppure
   `SOLO TEST AUTOMATICI`. Mai lasciarlo sottinteso.
4. Usare **sempre lo schema qui sotto**, con gli stessi titoli e nello stesso ordine. Se un punto e' vuoto scrivere «niente».
5. Mentre si lavora, la prima riga dice `IN LAVORO da <ora>: <cosa>`; a fine sessione `FERMO dalle <ora>`. Prima di
   scrivere su GitHub controllare che l'altra AI non sia `IN LAVORO` (vedi «Una sola AI modifica»).

Schema (copiare cosi' com'e'):

```
Stato: IN LAVORO da <gg.mm hh:mm>: <cosa> | FERMO dalle <gg.mm hh:mm>
Scritto da: <Claude|ChatGPT>, <data ora>, ultimo commit <sha corto>

1. In una riga: <a che punto siamo>
2. Fatto in questa sessione (max 5 punti, ognuno con PROVATO IN TF3 / PROVATO SUL PC / SOLO TEST AUTOMATICI)
3. Stato del PC: versione mod installata, middleware sul PC aggiornato si'/no, gioco aperto/chiuso,
   opzioni di avvio di Steam, file lasciati a meta'; autorizzazioni avute in questa sessione
4. Problemi aperti e cose da NON fare
5. Domande o decisioni per l'altra AI (o per Nicolo')
6. Prossima operazione precisa (1-3 passi, il primo eseguibile subito)
Letto da <altra AI> il <data>: <si' / dubbi>
```

## Istruzioni handoff per ChatGPT

*(scritta da Claude, letta da ChatGPT)*

```
Stato: FERMO dalle 17.10 (Claude)
Scritto da: Claude, 17.10.2026, ultimo commit b6e6a4c (tuo checkpoint 14.10) + questo
```

1. **In una riga:** nuova funzione richiesta da Nicolo': cambiare i segnali gia' costruiti da senso unico a doppio
   senso e viceversa. Scritta e testata solo con test automatici; va provata in TF3.
2. **Fatto da Claude (17.10):**
   - Mod (bozza `b6_binari.lua`): `CC.findSignals` (segnali in un raggio o su tutta la mappa),
     `CC.setSignalOneWay` e azione `set_signals_one_way` (`one_way`, `near_id`, `radius`, `max`, `apply`).
     Metodo: binario tolto e rimesso uguale, vecchio segnale tolto (`edgeObjectsToRemove`, se il comando lo
     rifiuta riprova senza) e segnale nuovo con stesso modello/posizione/verso e `oneWay` cambiato.
     Fuori dal registro di "annulla" (`NO_TX` in b9): i binari rifatti non devono essere tolti. SOLO TEST AUTOMATICI
     (mock 159 ok).
   - Console (`tools_bozza.py`, `main.py`): `check_signals` (solo conteggio) e `set_signals_one_way` (con
     conferma). Test middleware 183 ok. SOLO TEST AUTOMATICI.
3. **Stato del PC:** non visto da Claude. Mod `mod/` NON rigenerata (`build --check --bozza` resta DIVERSO, come da
   tuo checkpoint). Nicolo' ha fatto una prova della console ("trasforma tutti i segnali in sensi unici"): la console
   ha risposto che non c'era lo strumento, nessuna azione inviata.
4. **Problemi aperti / da NON fare:** non dire che funziona in TF3 finche' non provata. La finestra del segnale in TF3
   ha una tendina "Senso unico" (screenshot di Nicolo'): esiste quindi un comando del gioco per cambiarlo; se una
   sonda trova un `api.cmd.make...` per i segnali (cercare "ignal" tra le funzioni di `api.cmd`) e' piu' semplice e
   sicuro che rifare il binario.
5. **Domande / per Nicolo':** prova in gioco su una COPIA della partita, a gioco con build `--dev --bozza` nuova.
6. **Prossima operazione precisa:**
   1. Con il PC: sonda sola lettura delle funzioni `api.cmd` con "ignal"/"EdgeObject" nel nome.
   2. Build `--dev --bozza`, installazione a gioco chiuso (backup), copia della partita, `check_signals` e poi
      `set_signals_one_way` su 1-2 segnali (`max` piccolo); verificare nella finestra del segnale "Senso unico".
   3. Poi i tuoi passi del 14.10 (navi Calliano, anello doppio).

Letto da ChatGPT il ...:

## Istruzioni handoff per Claude
*(scritta da ChatGPT, letta da Claude)*

Stato: FERMO dalle 14.10 18:51: cinque correzioni verificate e pubblicate
Scritto da: ChatGPT, 14.10.2026 14.10 18:51, ultimo commit verificato 670c5c8 + questo checkpoint

1. In una riga: bridge e collaudo corretti senza PC; Calliano/anello aperti, mod NON finalizzata.
2. Fatto in questa sessione (max 5 punti, ognuno con PROVATO IN TF3 / PROVATO SUL PC / SOLO TEST AUTOMATICI)
   - SOLO TEST AUTOMATICI: cache bridge aggiornata solo su lettura riuscita; bridge-stato-lettura.md.
   - SOLO TEST AUTOMATICI: timeout ignoto non diventa ritirata, nonce/metadati preservati;
     bridge-timeout-sconosciuto.md. Nessun reinvio cieco di ID pendenti.
   - SOLO TEST AUTOMATICI: risultati letti non liberano ID prima dello stato; bridge-risultato-stato.md.
     Ricevute solo in memoria del GameBridge; stato invalido blocca invio, nessun salto ID.
   - SOLO TEST AUTOMATICI: collaudo navale non certifica API incompleta, fallback10/12;
     collaudo-navale-non-verificabile.md. Terra invariata; native_route.available = letture complete.
   - SOLO TEST AUTOMATICI: sosta terminale/deposito distinta da movimento (vehicles_waiting);
     collaudo-soste-movimento.md. Suite183/1skipWindows, mock150, CI38601254902 e revisione verdi.
3. Stato del PC: NON osservabile dalla sessione Linux; nessun controllo Windows disponibile.
   Installazione, middleware, TF3/Steam, opzioni e file sul PC NON verificati né modificati.
   Build dev db0a682b generata e sintassi Lua5.4 valida; NON installata. Release mod invariata.
   Nicolo' ha dato «accesso a tutto» in QUESTA chat; restrizioni STATO conservate, chiave vietata.
   Nuova chat verifica accessi e chiede permessi necessari; l'autorizzazione non si trasferisce.
4. Problemi aperti e cose da NON fare
   Normale costa ancora ipotesi; Calliano senza percorso nativo, anello doppio incompleto.
   Non presumere TF3 chiuso/PC raggiungibile; niente navi duplicate, installazione solo a gioco chiuso.
   Non riavviare un bridge con richieste irrisolte senza riconciliare stato/azioni/risultati effettivi.
5. Domande o decisioni per l'altra AI (o per Nicolo')
   Niente permessi pendenti qui. Manca il collegamento tecnico PC; prove TF3 NON eseguite.
6. Prossima operazione precisa (1-3 passi, il primo eseguibile subito)
   1. Leggere le cinque note e controllare nuovo main/accessi; build attuale db0a682b, non 7b47b5f9.
   2. Con PC autorizzato: s41 sola lettura, backup/installazione bozza e middleware aggiornati a gioco chiuso.
   3. Due campioni sosta/viaggio e Calliano su copia separata secondo prova-navale-linea.md;
      guardia preacquisto attiva. Poi riprendere anello senza riusare copia contaminata.
Letto da Claude il 17.10.2026: si'.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` (in particolare la sezione «Istruzioni handoff per» te, scritta dall'altra AI) e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica la tua sezione di `HANDOFF.md` (schema comune, max 40 righe) dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

Ogni AI **sostituisce** soltanto la propria sezione («Istruzioni handoff per ChatGPT» la scrive Claude, «Istruzioni handoff per Claude» la scrive ChatGPT) a ogni checkpoint, con lo schema comune, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

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

Stato: FERMO dalle 14.10 (lavoro senza PC concluso)
Scritto da: Claude, 14.10.2026, dopo il commit 50 + questo commit

1. In una riga: collaudo movimento provato in TF3; porti orientati sulla costa scritti ma NON provati in TF3.
2. Fatto (13-14.10):
   - Campioni movimento salvati nello stato della mod: PROVATO IN TF3 (2a check_line 25246 vehicles_moving=1).
   - Sonda s40 fondale Calliano-Lissone, collo 5.44 m: PROVATO IN TF3 (sola lettura). Non e' il fondale.
   - Porti sulla normale della costa (`CC.coastNormal`, b4): SOLO TEST AUTOMATICI (mock 150 ok). Sonda s41 pronta.
   - RETTIFICA: il commit 50 e la versione precedente di questa sezione dicevano «TF3 CHIUSO»: falso, non verificato.
3. Stato del PC (ultimo noto, 14.10 mattina, da Nicolo'): TF3 e Steam erano APERTI; la sessione Claude e' rimasta
   attiva tutta la notte su una richiesta di permesso. Mod installata v14-bozza-303c0edf (backup
   `capocantiere.script.lua.bak_samples_20261013_2133`). Build 7b47b5f9 NON installata. File actions/results 1-4
   in mod_presets. Nessun salvataggio nuovo fatto da Claude. Autorizzazioni del 13.10 NON valgono piu'.
4. Problemi aperti / da NON fare: Calliano senza percorso nativo (causa non trovata); anello doppio non fatto.
   Chiusura: seguire STATO.md sezione 1, punto 5 (verificare che TF3 sia chiuso e Steam su «GIOCA»).
   Niente navi duplicate; installare solo a gioco chiuso con backup.
5. Domande per Nicolo' (all'avvio, un solo messaggio): accesso PC/cartelle, chiudere/avviare TF3, installare
   7b47b5f9 con backup, caricare una copia, costruire su copia separata un porto/linea navale a Calliano.
6. Prossima operazione precisa:
   1. Con PC: sonda s41 in sola lettura (normale a Lissone stock ~(.776,-.631)?).
   2. Se si': installare 7b47b5f9 e provare una linea navale Calliano-Lissone su copia separata (guardia attiva).
   3. Se no: porto del gioco vicino a Calliano come confronto (vedi prova-navale-linea.md 14.10).

Letto da ChatGPT il 14.10.2026: si'.

## Istruzioni handoff per Claude
*(scritta da ChatGPT, letta da Claude)*

Stato: IN LAVORO da 14.10 18:23: cache stato bridge e timeout
Scritto da: ChatGPT, 14.10.2026 14.10 18:23, ultimo commit verificato 6f7b068 (branch movimento)

1. In una riga: ripresa autonoma senza PC; verifica cache bridge, Calliano/anello aperti.
2. Fatto in questa sessione (max 5 punti, ognuno con PROVATO IN TF3 / PROVATO SUL PC / SOLO TEST AUTOMATICI)
   - SOLO TEST AUTOMATICI: cache bridge/timeout/ricevute corretti, CI Ubuntu/Windows verdi;
     note bridge-stato-lettura.md, bridge-timeout-sconosciuto.md, bridge-risultato-stato.md.
   - SOLO TEST AUTOMATICI: native_route.available distingue dati incompleti da noPath; fallback10/12.
     CI38600520515 verde, nota collaudo-navale-non-verificabile.md.
   - SOLO TEST AUTOMATICI: AT_TERMINAL/IN_DEPOT fermo non conta piu' movimento; vehicles_waiting.
     Quattro regressioni prima rosse, ora verdi; nota collaudo-soste-movimento.md.
   - SOLO TEST AUTOMATICI: suite183/1skipWindows e mock150 verdi; revisione senza blocchi.
     Branch movement-waiting in attesa CI; mod release/installata invariate.
   - SOLO TEST AUTOMATICI: build dev0b20c9f6 precedente questa correzione; non installarla come ultima.
3. Stato del PC: NON osservabile da questa sessione Linux; nessun controllo Windows disponibile.
   Installazione, middleware, TF3/Steam, opzioni e file sul PC NON verificati né modificati.
   Nicolo' ha dato «accesso a tutto» in questa chat; restrizioni STATO conservate (chiave vietata).
   Autorizzazione di questa chat non trasferibile a una nuova chat.
4. Problemi aperti e cose da NON fare
   Calliano senza percorso nativo; normale costa ancora ipotesi, anello doppio incompleto.
   Non presumere PC raggiungibile o TF3 chiuso; niente navi duplicate né installazioni a gioco aperto.
   s41 available=true significa letture complete, NON rotta navale o orientamento certificati.
5. Domande o decisioni per l'altra AI (o per Nicolo')
   Niente permessi pendenti qui: manca tecnicamente il collegamento PC. Nuova chat verifica accessi/permessi.
6. Prossima operazione precisa (1-3 passi, il primo eseguibile subito)
   1. Verificare CI conteggio movimento e integrare main dopo controllo remoto; generare nuova build dev.
   2. Con PC: s41 sola lettura, poi installazione bozza aggiornata a gioco chiuso con backup.
   3. Misurare due campioni durante sosta/viaggio; Calliano su copia separata, guardia preacquisto attiva.
Letto da Claude il 14.10.2026: non ancora.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` (in particolare la sezione «Istruzioni handoff per» te, scritta dall'altra AI) e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica la tua sezione di `HANDOFF.md` (schema comune, max 40 righe) dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

Ogni AI **sostituisce** soltanto la propria sezione («Istruzioni handoff per ChatGPT» la scrive Claude, «Istruzioni handoff per Claude» la scrive ChatGPT) a ogni checkpoint, con lo schema comune, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

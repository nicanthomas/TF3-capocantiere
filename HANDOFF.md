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
Stato: FERMO dalle 12.10 (Claude)
Scritto da: Claude, 12.10.2026, ultimo commit c9855a5 (il tuo checkpoint 11.10)
```

1. **In una riga:** console Claude provata davvero in TF3 (2 richieste ok); da 10.10 c'e' stato solo lavoro di
   robustezza e test, nessun passo avanti nel gioco. Serve tornare a provare la mod nel gioco.
2. **Fatto da Claude (09-10.10):**
   - Avvio della console insieme al gioco da Steam (`middleware/avvia_con_gioco.bat`): PROVATO SUL PC, funziona
     (attende nel menu, «console pronta» quando carichi la mappa con la mod).
   - Console vera con Claude: «panoramica della mappa» e «fammi una linea bus a Lissone» — PROVATO IN TF3, linea
     costruita e collaudata. Costo: 30'790 token per 2 richieste.
   - Ho letto il tuo lavoro del 10-11.10 (85 commit): ok, ma il tuo checkpoint era troppo denso; da ora usa lo schema sopra.
3. **Stato del PC:** mod installata `v14-bozza-32c86032`; nel repo c'e' `v14-bozza-399dcf74` (non installata).
   Middleware sul PC in `<dati TF3>\local\capocantiere\middleware`, aggiornato a main del 09.10 tranne
   `avvia_capocantiere.bat` (sul PC la vecchia da 435 byte; la nuova attiva da sola le azioni v14). Opzioni di avvio
   di Steam: `avvia_con_gioco.bat %command%` (messe da Nicolo').
4. **Problemi aperti / da NON fare:** il .bat in uso dalla console non si sovrascrive col gioco aperto. Il primo
   «partita in pausa» del 10.10 non e' un errore confermato (al secondo tentativo ha funzionato).
5. **Domande per ChatGPT:** niente. **Per Nicolo' (da chiedere tu, ChatGPT, appena riprendi, in un solo messaggio):**
   autorizzazione a installare mod e `.bat` sul PC con il gioco chiuso, ad avviare TF3 e caricare la partita
   «capocantiere v14 prova», e a fare con lui una richiesta in console che costruisce. Senza queste i passi 1-2 non si fanno.
6. **Prossima operazione precisa:**
   1. Con il gioco chiuso: copiare `avvia_capocantiere.bat` e la mod `--dev --bozza` di main sul PC (backup prima,
      rileggere dal PC che i file coincidano).
   2. Con Nicolo': terza richiesta in console con un'azione v14 (es. «controlla la flotta della linea Lissone Bus»).
   3. Poi funzioni nuove nel gioco (doppio binario, porto), non altra robustezza interna.

Letto da ChatGPT il 12.10.2026: si'.

## Istruzioni handoff per Claude
*(scritta da ChatGPT, letta da Claude)*

Stato: IN LAVORO da 13.10 06:33: collaudo nave e doppio binario
Scritto da: ChatGPT, 13.10.2026, ultimo commit verificato 6daff8b
1. In una riga: porto/deposito costruiti, nave comprata ma assegnazione fallita; mod NON finalizzata.
2. Fatto in questa sessione (max 5 punti, ognuno con PROVATO IN TF3 / PROVATO SUL PC / SOLO TEST AUTOMATICI)
   - PROVATO IN TF3: quota terreno rifiuta deposito, acqua+2 lo costruisce nello stesso punto;
     deposito120768 raggiunge porto115052. Copia deposito quota13-10 salvata e verificata.
   - SOLO TEST AUTOMATICI: quota reale acqua+2 corretta, terra invariata, acqua assente blocca.
     CI verde; Lua esterno Windows saltato, non superato.
   - PROVATO IN TF3: deposito Lissone fallisce, a Calliano riesce103939/118853;
     copia separata salvata. SOLO TEST AUTOMATICI: ricerca tra tutte le citta' corretta, CI verde.
   - PROVATO IN TF3 A SECCO: fix estremi elimina collisione+5m, proposta88segmenti valida;
     lati-5/-10 ancora collidono con altre strade. Nessun comando costruttivo inviato.
   - PROVATO IN TF3: versione56eb18f5 costruisce porti121162/120860 e deposito117738;
     nave118966 in deposito, linea119497 vuota; API nativa segnala nessun percorso tra porti.
     PROVATO IN TF3: collaudo installato segnala entrambi i percorsi mancanti, nessuna costruzione.
3. Stato del PC: prototipo+10m fallito, copia 'capocantiere porto acqua10 fallito13-10' salvata.
   Installata v14-bozza-5f189de4 DEV_MODE true, backup/hash verificati; include fix collaudo.
   Opzioni Steam intatte; manifest mod ripristinato da backup, hash verificato.
   Copie quota e Calliano salvate; dati privati e helper in work della chat.
4. Problemi aperti e cose da NON fare
   Nave118966 IN_DEPOT, linea119497 senza veicoli; non ripetere acquisti o costruzione su questa copia.
   Lua TF3 e'5.2: mock math.maxinteger inapplicabile; CI Lua5.3/5.4 verde, distinguere runtime.
   Copia anello fallito conserva3stazioni/98tratti: non ricostruire li' o rimuoverli a mano.
   Non applicare riduzione bus79575; installare solo a gioco/console chiusi, backup verificato.
   Note: deposito-navale-quota.md, ricerca-deposito-navale.md, parallelo-estremi-strade.md, pc-focus-13-10.md.
5. Domande o decisioni per l'altra AI (o per Nicolo')
   Autonomia richiesta fino ai crediti; PC/Steam/TF3, checkout/rete, mod/middleware/scambio/log,
   backup, avvio/chiusura, console/API e pulizia protocollo autorizzati in questa chat.
   Direttive: bus Abriola-Maretto; anello doppio e porto/linea nave su copie separate.
   Minimizzazione AggiornamentiPC autorizzata; app ora assente, nessuna minimizzazione eseguita.
   Focus TF3 disponibile e verificato; nessun altro permesso attualmente necessario.
6. Prossima operazione precisa (1-3 passi, il primo eseguibile subito)
   1. Porto stock122925/gruppo125886 costruito; sostituire prima fermata25246 e assegnare nave123908.
   2. Prima di costruire verificare raccordi/scelta geometrica; poi copia iniziale ferrovia separata.
   3. Riprendere porto: confronto API nativa e CC.hasPath, poi bacino/accesso reale. Non comprare duplicati.
Letto da Claude il ...: ...

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` (in particolare la sezione «Istruzioni handoff per» te, scritta dall'altra AI) e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica la tua sezione di `HANDOFF.md` (schema comune, max 40 righe) dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

Ogni AI **sostituisce** soltanto la propria sezione («Istruzioni handoff per ChatGPT» la scrive Claude, «Istruzioni handoff per Claude» la scrive ChatGPT) a ogni checkpoint, con lo schema comune, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

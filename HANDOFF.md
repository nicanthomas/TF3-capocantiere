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

**Stato:** 10.10.2026 (ChatGPT/Codex locale Windows). Ricontrollo non distruttivo dopo spazio liberato da Nicolo': C: 28.310.061.056 byte liberi (28,3 GB), E: 709.994.942.464 byte (710,0 GB). Blocco disco risolto al controllo; nessuna installazione effettuata. Nessun file locale modificato dall'agente, nessun salvataggio letto/modificato e nessuna azione inviata al gioco.
Head remoto verificato prima del checkpoint: `e9f1946a85fb9d2ebce804f9d90f968e73d717b3` (10.10.2026-03). Il commit 02 corregge il checkpoint 01: la pausa NON e' un bug confermato. CI di questo head: successo, run `38032270281`; 8 test locali esistenti (parser Lua, validazione, cronologia) OK sul middleware installato, senza file scritti e senza API. Lettura tramite GameBridge.state() OK; nessuna chiamata send()/ping(). Risultati storici dopo i merge, riportati da Claude: middleware 37 OK, mock 71 OK, `build_script.py --check --bozza` OK.

| Campo | Valore |
| --- | --- |
| Ultima AI che ha aggiornato | ChatGPT / Codex desktop, controlli locali Windows |
| Branch | solo `main` (le branch `lavoro/flotta-iniziale` e `lavoro/avvio-con-gioco` sono unite; PR #2 chiusa) |
| Mod nel repo | `v14-bozza-399dcf74` (DEV_MODE false) = v14 + numero iniziale di veicoli |
| PC / gioco (09.10 ~18:30) | mod installata `v14-bozza-32c86032` (senza flotta iniziale); middleware sul PC in `<dati TF3>\local\capocantiere\middleware` aggiornato a main (backup in `capocantiere\backup\middleware_09.10.2026`); Steam avvia la console con il gioco |

### Capacita' verificate in questa sessione (10.10.2026)

- **File locali, sola lettura: OK** tramite PowerShell. Verificate cartelle dati `capocantiere`, `capocantiere/middleware`, `mods/tfcapocantiere_1`, `mod_presets`, `crash_dump`. Scrittura locale NON provata: questa fase e' limitata a controlli non distruttivi; mantenere backup e autorizzazioni del progetto.
- **Terminale e Node REPL: ora OK anche nel sandbox ordinario**, riprovati dopo aver liberato spazio, senza cambiare configurazioni. PowerShell 5.1.26100.9444. Il precedente errore MXC non si riproduce nel controllo attuale: non modificare il sandbox preventivamente.
- **Python: OK**, 3.10.10, interprete e launcher `py` funzionanti. Pacchetto `anthropic` presente; `pytest` e `lupa` non rilevati. Nessuna chiave API letta/usata e nessun pacchetto installato.
- **Git e checkout locale: non trovati** nel PATH e nella ricerca circoscritta (19.465 cartelle, profondita' massima 6) sotto profilo utente, Program Files/ProgramData e dischi D:/E:/F:/G:. Esclusi contenuti Steam, cartelle di sistema/cache e percorsi inaccessibili. Nessuna ricerca prova l'assenza assoluta: nessuna copia clonata per evitare duplicati. Middleware installato presente, ma non e' un checkout completo. Winget disponibile; proposta Git ufficiale, NON installato.
- **GitHub: lettura OK**, connettore riporta permesso push; la pubblicazione di questo checkpoint costituisce la prova di scrittura e deve essere riletta dopo il commit. Niente PR e niente force-push.
- **Steam: eseguibile presente e processo attivo**. **TF3: manifest ed eseguibile presenti** nella libreria `E:\SteamLibrary`, ma nessun processo `transportfever3` rilevato. Controllo grafico/clic non disponibile fra gli strumenti esposti: avvio, caricamento e chiusura del gioco NON provati.
- **Installazione effettiva letta:** mod `v14-bozza-32c86032`, `DEV_MODE = true`; avviatore `avvia_capocantiere.bat` ancora 435 byte, coerente col precedente handoff. State.lua residuo: stessa versione, lastActionId 1, speed 0; dato storico a gioco chiuso, NON una misura della partita attuale.
- **Spazio liberato confermato:** C: 28,3 GB, E: 710,0 GB (unita' decimali). Test Python locali: 8 OK; lettura dello state residuo tramite bridge OK (11 citta', 5 linee; file vecchio di circa 159 min al controllo), serializzazione richiesta Lua OK. TF3 chiuso: scambio vivo Python -> Lua -> Python NON provato. Nessuna cancellazione, spostamento, installazione o modifica alla configurazione eseguita.

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

1. Completare controlli in sola lettura degli strumenti nativi di avvio/interazione Windows e preparare piano operativo con autorizzazioni separate; non avviare ancora TF3, non usare la chiave API.
2. Proporre Git for Windows: `winget install --id Git.Git -e --source winget` (https://git-scm.com/install/windows). Installare solo dopo autorizzazione esplicita, poi verificare `git --version`.
3. Dopo scelta/autorizzazione cartella e ultima ricerca duplicati, creare un unico checkout completo, leggere AGENTS.md, verificare head e test Python/mock Lua/build. Lua standalone non trovato nel PATH; prima verificare i requisiti del mock del repo.
4. Con autorizzazione a modificare i file del gioco: a gioco chiuso, backup e aggiornamento avviatore; poi build `--dev --bozza`, backup/installazione/rilettura. Permessi per `mod_presets` da confermare prima di scrivere una richiesta, anche di sola lettura.
5. Prove vive ancora da fare: ping/lettura senza costruzioni, chiusura console con gioco, terza richiesta v14 e costo, flotta stimata/misurata, timeout tardivi. Non rimuovere il controllo pausa sulla base del checkpoint 01 superato.

## Prompt unico per aprire una chat vuota (Claude o ChatGPT)

> Riprendi lo sviluppo del progetto `https://github.com/nicanthomas/TF3-capocantiere`. Parti da una chat senza memoria precedente. Leggi `HANDOFF.md` e `dev-notes/note/STATO.md`, verifica gli ultimi commit su `main` e le istruzioni di sicurezza. Continua autonomamente dal checkpoint e dalla prossima attività realizzabile con gli accessi effettivamente disponibili. Tu e l'altra AI, o una futura nuova chat della stessa AI, vi alternate senza preavviso quando terminano crediti o contesto: aggiorna e pubblica `HANDOFF.md` dopo **ogni passo significativo**, insieme alle modifiche, senza aspettare una mia richiesta. Distingui test automatici e prove reali in TF3; non inventare risultati e non presumere accesso al PC. Rispetta le regole del repository, non fare operazioni rischiose o in gioco senza le autorizzazioni previste. Non chiedermi di riassumere la chat precedente: usa GitHub come fonte condivisa.

## Manutenzione

**Sostituire** il contenuto di «CHECKPOINT OPERATIVO CORRENTE» a ogni checkpoint, senza accumulare un diario cronologico infinito. Non eliminare le regole, il prompt o evidenze tecniche custodite altrove. La cronologia completa resta nei commit GitHub e nelle note sotto `dev-notes/note/`.

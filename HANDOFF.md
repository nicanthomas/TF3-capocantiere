# HANDOFF — passaggio di lavoro tra Claude e ChatGPT

> Documento operativo condiviso. Leggere **prima** `dev-notes/note/STATO.md` per regole, architettura e stato tecnico. Questo file non sostituisce `STATO.md`.

## Come funziona

- Il passaggio è **manuale**: solo Nicolo' decide quando Claude si ferma e ChatGPT riprende, o viceversa.
- GitHub è la fonte condivisa. Prima di iniziare, leggere la versione aggiornata dei file e verificare il commit corrente.
- **Una sola AI modifica il progetto alla volta.** Prima del passaggio, completare e pubblicare il lavoro oppure descrivere esplicitamente le modifiche non pubblicate.
- Non considerare mai una prova eseguita in Transport Fever 3 se è stata fatta solo con mock, test automatici o analisi del codice.
- ChatGPT, senza accesso al PC, può analizzare il repository, preparare patch e revisioni e usare gli strumenti disponibili; non può dichiarare di avere avviato TF3 o verificato direttamente il gioco.
- Rispettare tutte le regole di `dev-notes/note/STATO.md`, incluse le autorizzazioni, le precauzioni sui file e la modalità di pubblicazione su GitHub.
- Non inserire credenziali, chiavi API, identificativi personali o percorsi contenenti dati sensibili.

## Ultimo passaggio

**Stato:** modello iniziale — **nessun passaggio di lavoro ancora registrato**. Compilare questa sezione al primo cambio effettivo di AI.

| Campo | Valore |
| --- | --- |
| Data e ora (con fuso) | Da compilare |
| AI che consegna | Da compilare |
| AI destinataria | Da compilare |
| Branch di lavoro | Da verificare |
| Ultimo commit verificato (SHA completo) | Da verificare al momento del passaggio |
| Modifiche non pubblicate | Da verificare |
| Obiettivo corrente | Da compilare |
| Stato del lavoro | Da compilare |

### Lavoro completato nella sessione
- Da compilare con fatti verificabili e riferimenti a file/commit.

### File modificati e motivazione
- Da compilare.

### Verifiche eseguite
| Verifica | Ambiente (mock / CI / TF3 reale) | Esito | Evidenza |
| --- | --- | --- | --- |
| Nessuna registrata per questo handoff iniziale | — | Non eseguita | — |

### Problemi aperti e rischi
- Da compilare; indicare eventuali crash, dati incompleti, bug riproducibili o dipendenze dall'accesso al PC.

### Prossimo passo consigliato
1. Leggere `dev-notes/note/STATO.md` e gli eventuali appunti specifici della funzionalità.
2. Verificare branch, commit e stato dei test.
3. Scegliere un'attività concreta e circoscritta; prima di eseguire azioni sul gioco, verificare autorizzazioni e ambiente.

### Accessi disponibili / mancanti
- GitHub: verificare nella sessione corrente.
- PC Windows, Steam, Transport Fever 3 e salvataggi: **non presupporre accesso**; verificare ogni volta.
- Permessi temporanei: non considerare validi i permessi di una sessione precedente.

## Procedura per chi consegna

1. Terminare il passo in corso in uno stato recuperabile. Non lasciare modifiche implicite o azioni in sospeso.
2. Registrare **commit SHA**, branch e stato di pubblicazione.
3. Aggiornare le sezioni "Ultimo passaggio" con obiettivo, modifiche, verifiche, problemi e prossimo passo.
4. Aggiornare `dev-notes/note/STATO.md` quando cambia lo stato tecnico reale del progetto, evitando duplicazioni.
5. Pubblicare seguendo le regole GitHub indicate in `STATO.md` e verificare che i file siano leggibili sul repository.
6. Comunicare a Nicolo' che il passaggio è pronto. Nessuna AI avvia autonomamente l'altra.

## Procedura per chi riprende

1. Leggere `HANDOFF.md`, `dev-notes/note/STATO.md` e i file citati.
2. Controllare se il commit indicato è ancora l'ultimo rilevante e se sono intervenute modifiche successive.
3. Distinguere tra risultati documentati, ipotesi, test automatici e verifiche reali nel gioco.
4. Riprendere dalla prossima attività senza ripetere inutilmente prove già documentate.
5. In caso di conflitto, documentazione obsoleta o accesso mancante, segnalarlo e non inventare risultati.
6. Prima di riconsegnare, aggiornare questo file.

## Messaggi rapidi

**Da Nicolo' a ChatGPT:**

> Riprendi TF3-capocantiere. Leggi HANDOFF.md e dev-notes/note/STATO.md dal repository, verifica commit e stato attuale, poi continua dalla prossima attività fattibile con i tuoi accessi. Non dichiarare prove in TF3 se non le hai realmente eseguite.

**Da Nicolo' a Claude:**

> Riprendi TF3-capocantiere. Leggi HANDOFF.md e dev-notes/note/STATO.md, verifica l'ultimo commit e gli accessi al PC, poi continua dalla prossima attività. Al termine aggiorna il passaggio per ChatGPT.

## Nota di manutenzione

Aggiornare **il contenuto del passaggio**, non accumulare un diario infinito: la cronologia dettagliata rimane nei commit e in `dev-notes/note/`. Non cancellare evidenze tecniche da altri file.

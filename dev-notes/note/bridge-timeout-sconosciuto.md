# Timeout: stato illeggibile non prova mancata esecuzione

14.10.2026, ChatGPT — SOLO TEST AUTOMATICI, fixture senza PC/TF3.

Dopo la correzione cache, _accepted catturava ancora un errore di stato e
ritornava False. send ritirava il file e dichiarava «ritirata, non eseguita»
anche senza una lettura valida di lastActionId. Riprodotto sia con stato
troncato dopo pubblicazione sia dopo il ritiro. In più un ID ancora pendente
poteva essere riusato con un nonce nuovo, perdendo la correlazione precedente.

Correzione: _accepted distingue True, False e None (sconosciuto). ID mancanti,
booleani, negativi, frazioni e stringhe non certificano accettazione.
Un timeout è ritirata solo dopo archivio riuscito e ricontrollo leggibile False.
In caso ignoto si conserva il nonce, si segnala GameTimeout.status=sconosciuta
con «NON ripeterla». Il ritiro dell'eventuale file pendente è ancora tentato,
ma il ritiro da solo non certifica che la mod non lo avesse già letto.

send blocca un nuovo invio se il prossimo ID coincide con uno ancora pendente,
prima di archiviare/scrivere. request_sent=False su questa guardia impedisce
al middleware di sovrascrivere nome/argomenti della vecchia richiesta. Le
richieste ignote realmente inviate conservano invece LATE_INFO per diario
ed eventuali risultati tardivi, come quelle accettate.

Cinque regressioni prima rosse (otto fallimenti nei subtest e un errore).
Otto nuove prove totali, incluse consegna tardiva una sola volta e preservazione
metadati. Suite167test/1skipWindows e mock150 verdi. Nessuna installazione.

Limiti: non certifica tempi di pubblicazione stato o atomicità del protocollo
reale; cache/mtime possono ancora non rilevare scritture con timestamp identico.
Resta da verificare il caso distinto: un risultato tardivo già raccolto mentre
lastActionId resta indietro può liberare troppo presto l'ID. Prossimo passo.

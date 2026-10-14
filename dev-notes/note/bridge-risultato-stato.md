# Risultato ricevuto prima dello stato: nessun riuso ID

14.10.2026, ChatGPT — SOLO TEST AUTOMATICI, fixture; nessuna prova PC/TF3.

Causa riprodotta: _collect_late consegnava il risultato e rimuoveva late[id].
Se lastActionId era ancora il precedente, send generava di nuovo lo stesso ID.
Succedeva anche dopo take_late_results e dopo una risposta normale quando
_wait_state_id non otteneva conferma. Il protocollo non puo' saltare semplicemente
al prossimo ID: la mod legge solo lastActionId+1.

Fix: _pending_sync conserva ID/nonce di ciascun risultato letto, nei tre rami:
risposta normale, ultima lettura dopo timeout e raccolta tardiva. La consegna
al chiamante non cancella la ricevuta. _next_id la rimuove solo quando uno
stato valido conferma lastActionId>=id; altrimenti blocca con sconosciuta,
request_sent=False prima di qualsiasi archivio/scrittura. Nessun salto ID.
Uno stato azzerato durante la sessione non elimina automaticamente le ricevute.

Preflight: lastActionId deve essere int non booleano e non negativo, e lo
stato deve essere dict; dati mancanti/lista/stringa/frazione impediscono invio.
Il modulo usa RuntimeError fisso senza dati grezzi. La mod esporta l'intero.

Sei nuove prove prima: quattro fallimenti e sei errori nei subtest IDinvalidi;
recupero stato gia' verde. Sette prove finali, inclusa ultima lettura timeout
aggiunta dopo revisione. Dopo conferma ID6 una vera richiesta fixture usa ID7.
Revisione indipendente senza blocchi. Nessuna installazione o API del modello.

Limiti: ricevute solo in memoria del singolo GameBridge, non salvate su disco.
Ricreare il bridge azzera questa protezione; prima di riprendere una partita
con richieste irrisolte occorre riconciliare stato/azioni/risultati effettivi.
Non prova atomicita' o tempi reali del gioco, ne' identifica univocamente la
partita. Se lo stato si azzera il blocco e' intenzionale, non un invito al reinvio.

Suite completa finale locale174test/1skipWindows e mock150 verdi; nessuna prova TF3.

# Parallelo ferroviario: strade agli estremi accorciati — 13.10.2026

SOLO TEST AUTOMATICI e analisi del sorgente, nuova correzione NON provata in TF3. La diagnosi reale del 12.10 resta distinta: i paralleli ±5/-10 m collidevano con strade, anello non costruito.

CC.parallelTrack accorcia la catena del primo binario con skipStart/skipEnd per lasciare i raccordi alle stazioni. I nuovi estremi possono essere nodi di un passaggio a livello del primo binario. Il codice originale spezza le strade soltanto per i nodi interni (i>1 e i<#nodes), quindi un estremo non agganciato che cade sul passaggio a livello genera un secondo nodo nel corpo della strada senza lo spezzamento necessario.

Regressione sintetica: catena di sei segmenti60m, strade ai due estremi della parte accorciata, parallelo5m. Deve sostituire entrambe le strade in due mezzi segmenti ciascuna, con nodi condivisi tra strada e binario nella stessa proposta. Una seconda verifica conserva l'esclusione degli estremi esplicitamente agganciati a nodi esistenti. Fixture componenti copiate come nell'API nativa.

CI38351132265 RED: logs stepMock mostrano esattamente due nuovi controlli falliti (spezzamenti e nodi condivisi), 115ok/2falliti; terzo controllo estremi agganciati passa. Windows passa. Un messaggio 'regressione intenzionale' appartiene al test del runner, non a un terzo difetto di questa correzione.

Fix minimo: eliminare la restrizione i>1/i<#nodes, mantenere not snap. Nessun ignoreErrors, rimozione manuale o costruzione nel gioco. CI38351450231 verde (mock117ok/0falliti); locale134test senza fallimenti/errori, classeLua saltata. Revisione senza blocchi. Unita main735f044; installata con backup/hash v14-bozza-56eb18f5 il13.10 ore07:51, NON provata in TF3. Va poi riprovata con proposta a secco sul save ferroviario fallito prima di costruire su una nuova copia. Non affermare che risolva tutte le collisioni con le strade di campagna.

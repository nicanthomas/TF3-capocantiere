# Bridge: stato troncato non diventa cache valida

14.10.2026, ChatGPT. SOLO TEST AUTOMATICI, Linux e fixture; nessun PC/TF3.

Causa: state() ritentava tre volte ma, se tutte fallivano, assegnava il nuovo
mtime e restituiva _state precedente o None. La prossima lettura saltava il
parsing finche' il file cambiava timestamp. send() poteva quindi pubblicare
con lastActionId obsoleto. Riprodotto con parser reale e file temporanei:
3 test falliti, 1 errore (richiesta inviata invece di blocco), 1 test transitorio verde.

Fix: cache e mtime cambiano insieme solo dopo load_userdata riuscito.
Dopo tre errori di parsing si solleva RuntimeError fisso senza dati grezzi.
La cache precedente resta disponibile solo se viene richiesto esplicitamente
refresh=False; una lettura normale non la presenta come fresca.
Cinque regressioni verdi; ripristino del vecchio metodo in un processo di
prova riproduce gli stessi quattro fallimenti anche col contratto RuntimeError.
Suite159test/1skipWindows e mock150 verdi, revisione indipendente senza blocchi.

Non certifica snapshot atomico del file scritto dal gioco, timestamp invariato
per scritture diverse, API native o comportamento TF3. Non modifica la mod.
Prossimo difetto da verificare: _accepted converte errori di lettura in False;
nel timeout questo puo' dichiarare ritirata una richiesta dall'esito ignoto.

CI38598136192 verde Ubuntu/Windows sul commit58 76af8cc; file remoti uguali ai locali.

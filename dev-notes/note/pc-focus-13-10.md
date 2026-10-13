# Focus PC durante la prova navale — 13.10.2026

La mod4e8640b2 e' installata, ma la nuova prova completa non e' partita: TF3 e' al menu principale. Controller Steam/TF3 verifica HWND/PID/percorso; SetForegroundWindow e AppActivate non hanno prodotto il focus verificato, i clic sono stati rifiutati. Il processo in primo piano si chiama AggiornamentiPC. Non inviati clic/tasti a quella applicazione, non chiusa o minimizzata.

Richiesta limitata a Nicolo' mediante domanda asincrona: minimizzare solo quella finestra lasciando gli aggiornamenti in esecuzione. In attesa di risposta, studio del codice/dati ferroviari gia' raccolti. Nessun tentativo di aggirare le guardie. Fonte Windows: [SetForegroundWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setforegroundwindow), restrizioni sul cambio di primo piano.

La correzione ricerca deposito e' verde in CI38349547194; Pythonlocale134test,0fallimenti/0errori,classeLua saltata17.037s. Quota e fallback verificati separatamente in TF3; questo non certifica ancora nave in servizio.

## Verifica successiva 07:49

Chiusura normale tramite WM_CLOSE inviata esclusivamente alla finestra TF3 con PID/percorso
verificati; funziona senza primo piano. Non terminato forzatamente alcun processo.
Tentativo --script con file esterno di sola stampa/uscita: rifiutato prima dell'esecuzione,
perche' il percorso assoluto e' interpretato come risorsa del filesystem virtuale.
Nessuna partita caricata/modificata; dialogo IOError chiuso normalmente, TF3 ora chiuso.
Non ripetere con percorsi inventati. API app.loadGame/app.saveGame presenti nelle definizioni
ufficiali locali; l'avvio esterno e la loro disponibilita' al menu non sono provati.

07:56: installata v14-bozza-56eb18f5 con backup/SHA256, contiene anche il fix ferroviario.
Riavvio normale: focus ancora trattenuto da AggiornamentiPC (verifica nome processo soltanto).
Nessun clic eseguito, nessuna mappa caricata, gioco richiuso normalmente.
Documentazione ufficiale [risorse TF3](https://wiki.transportfever3.com/doku.php?id=modding%3Ageneral%3Aresourcetypes)
definisce il prefisso mod_id::/ per le risorse di una mod; avvio con risorsa mod non ancora provato.

## Avvio da risorsa mod riuscito, 08:02

Risorsa tfcapocantiere_1::/capocantiere/boot_noop_13_10.prog.lua aggiunta solo alla mod sul PC;
manifest _content.json salvato prima e hash backup uguali. --script ora esegue realmente il codice.
Log filtrato mostra due contesti app=false e un contesto app disponibile (tabella);
app.quit(false) chiude normalmente il gioco. Processo assente dopo la prova.
Nessuna partita caricata, niente clic/tasti, nessun controllo di AggiornamentiPC.
Le funzioni app sono oggetti richiamabili: type(app.loadGame)='table', non 'function'.
Il codice della sonda controlla soltanto presenza, stampa e chiude; non altera il mondo.
Non certifica ancora caricamento/salvataggio con API. File lasciato nella mod, manifest con backup.

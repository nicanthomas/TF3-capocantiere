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

## Rettifica verifica uscita e ripristino, 08:01

La sola assenza di finestre visibili NON certificava uscita normale. Processi della sonda
rimasti con dialoghi Lua error nascosti (avvio WindowStyle Hidden). Il log riporta
'function data() not defined' e 'Ungraceful exit': codice eseguito ma programma incompleto.
Seconda sonda legge realmente elenco28salvataggi, elementi userdata, pairs non applicabile;
nessuna partita caricata. Non pubblicati log con percorsi/identificativi personali.
Dialoghi della sola TF3 chiusi normalmente con PID/percorso/titolo verificati, nessun kill.
Processi assenti verificati; manifest originale ripristinato da backup, SHA256 uguali.
File sonda conservato fuori manifest: nessuna azione all'avvio normale.
Nicolo' autorizza minimizzazione AggiornamentiPC; vecchia finestra non piu' valida e processo
ora assente. Guardie hanno bloccato i tentativi, nessuna minimizzazione o chiusura effettuata.
Ripresa avvio normale TF3, non altre prove --script durante questo collaudo.

## Caricamento/salvataggio da API confermati in gioco

app.saveGame gia' provato sulla copia nave fallita13-10, callback e SAV/JPG verificati.
app.loadGame ora PROVATO IN TF3: scelta univoca di 'capocantiere test porto12-10'
(nome esatto con spazio prima12), dati SaveGameInfo copiati in api.type.SavegameId.new().
Campi path/saveGameName/saveGameNamespace come nello script ufficiale savegame_react_util.tl:869.
Senza setWaitForStartReadyGame il caricamento avvia direttamente la simulazione: stato recente,
mod5f189de4, speed4, scena copia iniziale senza porti della prova fallita. Nessun clic necessario.
Non usare mai nomi generici o ultimi salvataggi per automazioni: copia richiesta deve essere univoca.

# Collaudo navale: mancante e non verificabile sono distinti

14.10.2026, ChatGPT — SOLO TEST AUTOMATICI Lua5.4 e API sintetica, NON TF3.

Causa: checkLine ignorava eccezioni, risposte incomplete e noPath non booleani
dell'API nativa. Se hasPath generico passava, ok poteva restare true e il
rapporto del middleware dire «funziona». Il grafo generico non certifica la
navigabilita': gia' PROVATO IN TF3 su Calliano, vedi collaudo-percorso-navale.md.
Cinque regressioni eseguono il codice reale sotto Lua5.4; prima tutte fallivano.

Fix b8: sulle sole linee navali, native_route.available richiede una riga per
fermata, almeno uno stato per riga e noPath booleano in ciascuno stato.
Stessa struttura gia' usata dalla guardia preacquisto b4; nessuna nuova API.
API assente/eccezione/risposta incompleta aggiunge il problema fisso «percorso
navale nativo non verificabile», quindi ok=false. Non prova percorso mancante.
noPath=true resta invece un percorso realmente mancante anche con dati
completi (native_route.available=true). Nessun testo grezzo di errore.

Fallback enum SHIP10/SMALL_SHIP12 allineati alla lettura reale documentata il
13.10 in collaudo-percorso-navale.md; i vecchi12/13 erano errati. Modo13 non
viene dichiarato navale. Gli enum disponibili mantengono priorita'.
Controlli terrestri invariati. Descrizione check_line aggiornata per evitare
che il modello confonda disponibilita' dei dati con successo del percorso.

Suite locale179test/1skipWindows e mock150 verdi. Cinque regressioni API e
fixture mock preesistente aggiornata per il nuovo contratto di lettura ignota.
Revisione indipendente senza blocchi. Il collaudo subito dopo la costruzione
propaga ok/problemi/suggerimenti; il nuovo campo completo e' su check_line.
Nessuna nuova azione, nessun acquisto, nessuna rimozione dal collaudo stesso.

NON risolve geometria Calliano, bacini, assegnazione o doppio binario.
Mod pubblicata/installata non rigenerata. Con PC occorre generare la bozza
sviluppo dai sorgenti aggiornati e provarla con backup a gioco chiuso.
I numeri versione303c0edf/7b47b5f9 sono storici: la nuova build avra' altro hash.

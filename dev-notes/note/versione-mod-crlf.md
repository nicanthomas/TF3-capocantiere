# Versione della mod generata su Windows: correzione del 12.10.2026

## Problema osservato realmente in TF3
Dopo backup, installazione con impronte coincidenti e caricamento di "capocantiere v14 prova",
la console e state.lua riportavano v14-bozza-399dcf74 invece della versione generata 4e61dfa4.
Lo script installato conteneva due dichiarazioni consecutive CC_VERSION: Lua usava la seconda.
Partita rimasta in pausa, zero chiamate API, nessuna costruzione; console e gioco poi chiusi normalmente.

## Causa e modifica
Il checkout Windows usa CRLF; read() preserva i terminatori.
La ricerca della dichiarazione ancorata alla fine riga non accettava il CR prima del newline.
set_version inseriva quindi una nuova dichiarazione davanti a quella esistente.
La correzione riconosce la dichiarazione con CRLF senza consumarne il terminatore.
Anche le stampe del generatore riconoscono la versione con CRLF; altrimenti stampavano "?".
Sorgenti Lua, schema protocollo, permessi e mod di distribuzione restano invariati.
Le impronte del codice possono differire fra checkout LF e CRLF: questa modifica non normalizza l'hash.

## Test automatici
Regressioni per aggiornamento LF/CRLF, terminatori misti, inserimento idempotente e copia dev
con versione stampata coerente coi byte scritti. Prima della correzione: due fallimenti versione;
una regressione aggiuntiva ha poi dimostrato la stampa "?". Dopo: regressioni verdi.
La suite Windows isolata finale ha 134 test, zero errori/fallimenti e una classe Lua saltata.
Manca ancora un runtime Lua Windows fidato; lo skip non e' una prova nativa.
CI 38275807791 verde su c4afd72; revisione indipendente senza blocchi e integrazione lineare in main.
Caricamento e versione corretti in TF3 ancora da riprovare.

## Prossima verifica reale
Con gioco e console chiusi: nuovo backup, rigenerare --dev --bozza da main corretto,
installare e confrontare; ricaricare la partita e verificare state.lua, poi controllo flotta in console.

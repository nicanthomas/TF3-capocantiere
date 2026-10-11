# Chiavi userdata rappresentabili - 11.10.2026

Riproduzioni solo stringhe: {[true]='fixture'} diventa lista di indice1, {[nil]='fixture'} accettato come dict None, tablekey causa TypeError raw. dumps accetta bool come int. In Python True/1 e False/0 collidono: non rappresentare silenziosamente tabelle Lua con chiavi distinte.

Design: reader ammette solo chiavi stringa/numeriche gia' supportate (int/float finiti), rifiuta booleani/nil/table con LuaParseError PRIMA assegnazione; writer rifiuta bool prima di qualunque scrittura, conservando le sue chiavi int/stringa. Booleani come VALORI invariati. Le chiavi bool sono legali in Lua, ma escluse consapevolmente da questo subset Python: nessuna promessa di rappresentazione di ogni tabella Lua. Chiavi float restano leggibili, writer rimane int/stringa come prima.

Quattro regressioni prima codice: boolkey/collisione, nil/table errori tipizzati, dumps/save rifiutati prima cambio file fixture, int/string/numeric/booleanvalues preservati. Backup privato; RED/GREEN/revisione/CI e verifica main prima merge. Nessun dato reale/mod/bridge vivo/API o installazione.

RED locale 127 test/7 fallimenti/2 errori/1 classe Lua skip, 16,280 s. Formati numerici/stringa e booleanvalues passano; produttivo invariato.

RED CI 38140623855 confermato Ubuntu141/Windows127 con7fallimenti/2errori. Solo dopo RED guardie reader/writer minime; doc modulo corregge nome inesistente dump_userdata con dumps/save_userdata, nessuna API nuova.

Locale GREEN127 OK/classeLua skip16,280s; revisione senza blocchi, CI prima merge.

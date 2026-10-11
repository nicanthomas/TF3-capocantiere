# Parser Unicode ed escape - 11.10.2026

Riproduzioni solo stringhe: roundtrip di U+00C3 seguito da U+00A9 cambia in U+00E9; Unicode non Latin-1 misto a byte UTF-8 escapati impedisce la ricomposizione. Nessun dato del gioco.

Design: testo Unicode letterale invariato; buffer solo delle sequenze consecutive di escape numerici, UTF-8 se valido altrimenti Latin-1 per quella sequenza. Non ricodificare l'intera stringa. Byte decimali 0..255, hex esattamente due cifre; errori LuaParseError. Escape gia' dichiarati e separatori preservati, nessuna nuova grammatica generale o supporto Unicode escape Lua. Il fallback e' una convenzione Python per esportazioni testuali, non un encoding richiesto da Lua ne' una API per byte arbitrari.

Riferimento primario: [Lua 5.3, convenzioni lessicali](https://www.lua.org/manual/5.3/manual.html#3.1): escape numerici rappresentano byte; non impone UTF-8. Sei regressioni prima del codice, backup privato; checkpoint RED poi implementazione/GREEN/revisione/CI prima merge.

RED locale: 115 test, 10 fallimenti/3 errori (subcase), 1 classe Lua skip, 16,316 s. Codice produttivo invariato. Nessun accesso gioco/ambiente/modello.

RED CI 38139166979 confermato: Ubuntu 129 test/10 fallimenti/3 errori/1 skip Windows, 14,362 s; Windows 115/10 fallimenti/3 errori/1 classe Lua skip, 14,385 s. Solo dopo RED implementato buffer per sequenze numeriche; Locale GREEN 115 OK/1 classe Lua skip, 16,335 s; revisione/CI GREEN in corso.

Rilievo revisione prima merge: flush prima di escape z spezza UTF-8 nonostante z non produca byte. Settima regressione aggiunta prima fix su decimal/hex/z con newline; prima correzione NON integrare. RED locale dedicato 116 test/3 fallimenti/zero errori/1 classe Lua skip, 16,265 s. CI RED dedicato 38139382189: Ubuntu 130/3 fallimenti/1 skip Windows, 14,111 s; Windows 116/3 fallimenti/1 classe Lua skip, 14,451 s. Solo dopo RED spostato z prima flush, Locale GREEN finale 116 OK/1 classe Lua skip, 16,254 s; CI finale in attesa.

Revisione finale: rilievo z risolto, nessun altro blocco. Locale finale 116 OK/1 classe Lua skip, 16,254 s. CI finale GREEN 38139535647 Ubuntu 130/1 skip Windows, 14,803 s; Windows 116/classe Lua skip, 14,494 s; mock 104/0; mai dati del gioco. Sequenze numeriche separate da testo/escape che produce carattere indipendenti; z non interrompe il run. Main ricontrollato prima merge.

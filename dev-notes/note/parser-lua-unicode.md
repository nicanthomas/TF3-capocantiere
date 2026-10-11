# Parser Unicode ed escape - 11.10.2026

Riproduzioni solo stringhe: roundtrip di U+00C3 seguito da U+00A9 cambia in U+00E9; Unicode non Latin-1 misto a byte UTF-8 escapati impedisce la ricomposizione. Nessun dato del gioco.

Design: testo Unicode letterale invariato; buffer solo delle sequenze consecutive di escape numerici, UTF-8 se valido altrimenti Latin-1 per quella sequenza. Non ricodificare l'intera stringa. Byte decimali 0..255, hex esattamente due cifre; errori LuaParseError. Escape gia' dichiarati e separatori preservati, nessuna nuova grammatica generale o supporto Unicode escape Lua. Il fallback e' una convenzione Python per esportazioni testuali, non un encoding richiesto da Lua ne' una API per byte arbitrari.

Riferimento primario: [Lua 5.3, convenzioni lessicali](https://www.lua.org/manual/5.3/manual.html#3.1): escape numerici rappresentano byte; non impone UTF-8. Sei regressioni prima del codice, backup privato; checkpoint RED poi implementazione/GREEN/revisione/CI prima merge.

RED locale: 115 test, 10 fallimenti/3 errori (subcase), 1 classe Lua skip, 16,316 s. Codice produttivo invariato. Nessun accesso gioco/ambiente/modello.

RED CI 38139166979 confermato: Ubuntu 129 test/10 fallimenti/3 errori/1 skip Windows, 14,362 s; Windows 115/10 fallimenti/3 errori/1 classe Lua skip, 14,385 s. Solo dopo RED implementato buffer per sequenze numeriche; Locale GREEN 115 OK/1 classe Lua skip, 16,335 s; revisione/CI GREEN in corso.

# Parser Lua: terminatori Windows - 11.10.2026

Riproduzioni solo stringhe: long literal CR/CRLF iniziale non ignorato, contenuto CRLF/CR/LFCR non normalizzato; backslash seguito da CRLF restituisce CRLF invece di un newline. Nuova sonda legge bytes/UTF-8 senza newline translation, quindi il solo open universale non copre tutti i chiamanti loads. Nessun file gioco letto.

Design circoscritto: long literal normalizza CRLF/LFCR/CR a LF e rimuove soltanto il primo newline se subito dopo apertura; breve escape backslash+newline normalizza e consuma una coppia CRLF/LFCR. Unicode, livelli parentesi, backslash letterali long e dumps invariati. Non aggiunge grammatica generale, non cambia gestione degli altri escape o newline brevi non escapati.

Quattro regressioni prima codice, backup privato; RED/GREEN/revisione e controllo main prima integrazione. Fonte primaria [Lua 5.3 convenzioni lessicali](https://www.lua.org/manual/5.3/manual.html#3.1), comportamento long literal e escape line break. Nessuna installazione, API, bridge vivo o file gioco modificato.

RED locale 123 test/7 fallimenti/1 classe Lua skip, 16,272 s. Formati/Unicode preservati passano. Codice produttivo invariato, CI RED prima fix.

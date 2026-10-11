# Validazione argomenti: numeri finiti - 11.10.2026

Riproduzione solo funzione pura: validate_args accetta NaN come interval anche con minimum/maximum, perche' entrambi i confronti sono false. Il main chiama validate_args e risponde argomenti non validi prima di run_local_tool/run_game_tool: miglioria preventiva senza eseguire main, SDK, modello o bridge.

Design: dopo validazione tipo, schema number + float non finito => errore singolo con percorso e messaggio fisso, return prima enum/bounds. math.isfinite SOLO per float, niente conversione interi arbitrari che causerebbe OverflowError. Valori finiti, integer, tipi/bounds/nesting/campi extra ignorati invariati. Non certifica range numerico Lua C++/id di gioco; nessuna nuova azione o automatismo.

Tre regressioni prima codice: entrambi schemi flotta reali NaN/+Inf/-Inf, array/object nested percorso esatto, finiti/interi enormi/tipi e bounds conservati. Backup privato; RED/GREEN/revisione/CI/main ricontrollato. [RFC8259 sezione6](https://www.rfc-editor.org/rfc/rfc8259#section-6) non ammette NaN/Infinity nella grammatica JSON; Python puo' comunque riceverli da input/test o estensioni parser. Nessuna chiave o chiamata Anthropic.

RED locale130 test/7 fallimenti/1 classe Lua skip, 16,332 s: NaN accettato e Inf non diagnosticato come non finito, nesting NaN accettato. Validi/interi enormi/tipi/bounds passano, codice produttivo invariato.

RED CI38141026312 confermato Windows/Ubuntu con7fallimenti, poi guardia minima math.isfinite solo float, return prima enum/bounds.

Locale GREEN130 OK/1 classe Lua skip, 16,360 s; revisione senza blocchi. Nicolo' ha chiesto stop: soltanto pubblicazione/checkpoint e rapporto, nessun nuovo sviluppo.

GREEN38141250728 Ubuntu 144/1 skip Windows,14,110s; Windows 130/classe Lua skip,14,400s; mock104/0, revisione senza blocchi; main ricontrollato prima integrazione. Locale 130 OK/1classeLua skip16,360s. Nessun nuovo sviluppo dopo stop, solo chiusura checkpoint.

# Lua obbligatoria nel collaudo isolato — 11.10.2026

Passo circoscritto nello sviluppo autonomo: --require-lua opt-in del runner Windows isolato. Default attuale conservato (Lua assente -> classe skip), flag esplicito -> REQUIRE_LUA=1 e policy della classe nativa gia' esistente (assenza -> errore, exit non zero). JSON indica lua_required per distinguere collaudo Python da futura parita' nativa. Venv/-I/-B, fixtures, audit, API key vuota nel figlio e blocchi rete/Steam invariati. Nessuna DLL reale caricata/ricercata/installata in questo passo.

Tre regressioni bootstrap usano la policy setUpClass reale dell'integrazione e un loader simulato: default assente, obbligatoria assente e disponibile simulata. Ambiente sintetico, niente lettura delle chiavi; discovery limitata a una singola classe probe senza esecuzione Lua. Ripristino di glob/tempdir e oggetti globali dopo ogni probe. I test NON provano un runtime nativo. RED prima del codice, GREEN e revisione prima dell'integrazione.

RED locale corretto: 93 test, 3 errori, 1 classe Lua skip, 16,136 s. Campo JSON lua_required mancante e argomento --require-lua non riconosciuto; runner produttivo ancora invariato. Primo probe corretto per sys.argv reale usato da argparse: guardia audit aveva bloccato fuori-fixture prima di scrittura. Nessuna modifica esterna.

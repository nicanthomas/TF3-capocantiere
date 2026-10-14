# Sonda costa: letture mancanti distinte da terreno asciutto

14.10.2026 — ChatGPT, solo ambiente Linux/Lua5.4; nessuna prova in TF3.

La sonda s41 usa `return ok and w == true`. Quando `isOnWater` solleva
un errore o restituisce nil/un valore non booleano, il campione diventa
asciutto. Un API del terreno assente causa invece un errore fuori dal pcall.
Una lettura parziale può quindi produrre una normale o una frazione ingannevole.
Il difetto è nella diagnosi: non dimostra la causa del percorso mancante a Calliano.

Sei regressioni eseguono il vero sorgente s41 con terreno sintetico in Lua5.4:
API assente, tutte letture fallite, metà nil, valore numerico, terra asciutta
valida e costa rettilinea valida. Prima della modifica tutte falliscono
per asserzioni sui dati mancanti; API assente fallisce per accesso a nil.
Un primo comando dalla radice aveva solo un errore di import: non è la
prova del difetto; la riproduzione valida è dal percorso middleware:
`CAPOCANTIERE_REQUIRE_LUA=1 python -m unittest test_lua_integration -k coast_probe`.

Correzione prevista: `available`, `read_count`, `read_errors` e codici errore
fissi; non restituire nx/ny/wet_fraction quando le letture sono incomplete.
Con tutte le letture valide conservare campionamento, arrotondamento e verso.
Nessun comando, file o processo del gioco; nessuna modifica alla geometria b4.

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

Correzione applicata: `available`, `read_count`, `read_errors` e codici errore
fissi; non restituire nx/ny/wet_fraction quando le letture sono incomplete.
Con tutte le letture valide conservare campionamento, arrotondamento e verso.
Nessun comando, file o processo del gioco; nessuna modifica alla geometria b4.

## Esito dopo la correzione

Sei regressioni passano: `available=false` per API assente o letture incomplete;
`read_count` conta i booleani validi, `read_errors` i campioni non leggibili.
Con API assente nessun campione viene tentato (entrambi zero); errori fissi
`terrain_api_unavailable` e `terrain_reads_incomplete`, senza messaggi privati.
Quando available=false non esistono nx/ny/wet_fraction. Con tutti i booleani
validi, campionamento e arrotondamento sono preservati. `available=true`
certifica solo che le letture sono complete, NON il percorso navale.

Suite locale: 154 test Python, zero errori/fallimenti, un test Windows saltato;
150 controlli mock verdi sotto Lua5.4 reale. L'output della suite include un
fallimento mock intenzionale: il test verifica proprio che il runner ritorni 1.
ResourceWarning già presenti in test_middleware non fanno fallire la suite.
`build_script.py --check` ritorna 1/DIVERSO, come prima: la mod pubblicata
non è allineata alla bozza; il workflow tratta il controllo come avviso.
Mod e middleware installati sul PC NON toccati; nessuna prova reale TF3.

Prossima prova con accesso tecnico al PC: eseguire s41 in sola lettura.
Se available=false per uno dei punti/raggi, fermare l'interpretazione della
normale e diagnosticare la lettura. Solo con dati completi confrontare il
verso al porto stock di Lissone, quindi seguire prova-navale-linea.md su una
copia separata. Non modificare il posizionamento per deduzioni dal mock.


## Pubblicazione e revisione

Correzione commit54 `ff9d77b`, dopo test commit53 `83a0528` su branch di lavoro.
CI [38596708540](https://github.com/nicanthomas/TF3-capocantiere/actions/runs/38596708540)
completata verde per Ubuntu e Windows. Revisione indipendente senza errori concreti
né regressioni. Prima dell'integrazione verificato main ancora57679bc; file della
branch pubblicata confrontati byte per byte con il checkout locale (tutti uguali).
Handoff e STATO aggiornati insieme; nessuna PR e nessun force-push.

# Capo Cantiere – LLM per Transport Fever 3

Dai ordini in italiano ("fammi una linea bus a Lanusei", "collega la cava di argilla al mattonificio")
e Claude li traduce in costruzioni nel gioco.

```
Tu ──▶ middleware Python (main.py) ──▶ Claude API (tool use)
                    │
                    ▼  file actions_<id>_<nonce>.lua / results_<id>_<nonce>.lua / state.lua
          cartella <dati utente TF3>/capocantiere
                    ▲
                    │
          mod Lua "Capo Cantiere" in TF3 (GUI legge i file, lato simulazione costruisce)
```

## Contenuto

| Cartella | Cosa c'e' |
|---|---|
| `mod/tfcapocantiere_1/` | La mod da copiare in `<dati utente TF3>/local/mods/` |
| `middleware/` | Console Python: `main.py` (chat con Claude), `game_bridge.py` (scambio file), `tools.py` (tool per Claude), `lua_table.py` (lettura/scrittura tabelle Lua) |
| `dev/` | Strumenti di sviluppo: libreria sim (`cc_lib.lua`, `cc_actions.lua`) usata per i test via eval, controllo sintassi Lua, mock |
| `docs/` | Scoperte sull'API di TF3 e cose da fare |

## Azioni supportate (tool di Claude)

| Tool | Cosa fa | Stato |
|---|---|---|
| `find_entity`, `get_overview` | Cerca citta'/industrie/stazioni/linee, riassunto mappa (locale, senza costi) | OK |
| `build_bus_line` | Fermate, deposito, linea e bus in una citta' | Provato in gioco (1900 e 2300) |
| `build_tram_line` | Binari tram sulle strade, fermate ad anello percorribile, deposito tram, tram (elettrici nelle epoche moderne) | Provato in gioco (1900 e 2300) |
| `build_station` | Una fermata bus vicino a citta'/industria | Provato |
| `build_line` | Linea tra stazioni esistenti | Provato |
| `buy_and_assign_vehicles` | Compra veicoli (deposito e modello automatici) e li assegna | Provato |
| `connect_industry_to_city` | Merci su strada industria → industria o citta' | Provato in gioco (1900 e 2300) |
| `build_rail_line` | Stazioni a 2 binari con scambi, binari con passaggi a livello, sovrappassi, sottopassi, ponti e gallerie, deposito, linea e treni tra 2+ citta' | Provato in gioco (1900 e 2300) |

Ogni azione che costruisce o compra chiede conferma prima di essere inviata.

## Installazione

1. Copia `mod/tfcapocantiere_1` in `C:\Program Files (x86)\Steam\userdata\<id>\3493540\local\mods\`
   e attiva la mod nella partita.
2. Python 3.10+, poi `pip install anthropic`.
3. Chiave API **solo** come variabile d'ambiente (mai nei file):
   `setx ANTHROPIC_API_KEY "..."` e riapri il terminale.
4. Controllo: `python middleware/verifica_installazione.py` (non modifica nulla).
5. Con la partita aperta: doppio clic su `middleware/avvia_capocantiere.bat`
   (oppure `python middleware/main.py`; se la cartella di scambio e' diversa: variabile `CAPOCANTIERE_DIR`).

Comandi della console: `/stato`, `/ping`, `/reset`, `/esci`.

## Note

- La mod scrive solo nella cartella `capocantiere` dei dati utente.
- `DEV_MODE = true` nello script abilita `lua_eval` / `sim_eval` (solo per sviluppo): da spegnere per l'uso normale.
- Modello Anthropic configurato in `middleware/main.py` (`MODEL`). Il middleware usa il prompt caching e tiene
  in memoria solo gli ultimi turni della conversazione (`MAX_TURNS`) per contenere i costi.
- Gli argomenti dei tool vengono controllati in Python prima di arrivare al gioco.
- All'avvio i file `actions_*` rimasti da sessioni precedenti vengono spostati in `capocantiere/vecchi`.

## Sviluppo

- `python middleware/test_middleware.py`: test del middleware senza gioco e senza API.
- `python dev/build_script.py`: copia `dev/cc_lib.lua` + `dev/cc_actions.lua` nello script della mod
  (con backup e controllo di sintassi); `--check` verifica soltanto che siano allineati.
- `dev/bozza/`: funzioni nuove ancora da provare in gioco (treni merci, bus tra citta', gestione veicoli, annulla,
  aerei/elicotteri/navi, superstrade); test senza gioco con `python3 dev/bozza/run_mock.py`.
- `dev/sonde/` e `dev/prove/`: codice da eseguire in gioco con `python dev/mkeval.py` (vedi `docs/piano-stasera.md`).

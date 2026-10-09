# Capo Cantiere – LLM per Transport Fever 3

## Ripresa sviluppo da chat vuota (Claude o ChatGPT)

Se sei un'AI che deve continuare lo sviluppo, apri **[HANDOFF.md](HANDOFF.md)** e poi **[STATO.md](dev-notes/note/STATO.md)**. Il checkpoint va aggiornato e pubblicato dopo ogni passo significativo, **senza attendere un avviso di cambio AI o chat**. Per iniziare una chat completamente nuova usa il **prompt unico** riportato in fondo a `HANDOFF.md`. Queste istruzioni valgono per Claude, ChatGPT e nuove conversazioni della stessa AI; non conferiscono automaticamente accesso a Windows o a TF3.

Dai ordini in italiano ("fammi una linea bus a Lanusei", "collega la cava di argilla al mattonificio")
e Claude li traduce in costruzioni nel gioco.

```
Tu ──▶ middleware Python (main.py) ──▶ Claude API (tool use)
                    │
                    ▼  file capocantiere_actions_<id>_<nonce>.lua / capocantiere_results_... / capocantiere_state.lua
          cartella <dati utente TF3>/mod_presets
                    ▲
                    │
          mod Lua "Capo Cantiere" in TF3 (GUI legge i file, lato simulazione costruisce)
```

## Contenuto

| Cartella | Cosa c'e' |
|---|---|
| `mod/tfcapocantiere_1/` | La mod da copiare in `<dati utente TF3>/local/mods/` |
| `middleware/` | Console Python: `main.py` (chat con Claude), `game_bridge.py` (scambio file), `tools.py` (tool per Claude), `lua_table.py` (lettura/scrittura tabelle Lua) |
| `dev-notes/` | Appunti e strumenti di lavoro, NON documentazione per gli utenti. Solo per lo sviluppo: libreria sim (`cc_lib.lua`, `cc_actions.lua`), build della mod, bozza delle funzioni nuove (`bozza/`), sonde e prove in gioco (`sonde/`, `prove/`), strumenti di prova (`strumenti/`) |
| `dev-notes/note/` | Note di sviluppo: stato del progetto (`STATO.md`), diario delle prove, scoperte sull'API di TF3 |

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

Azioni della v14 (bozza: si attivano con `CAPOCANTIERE_BOZZA=1` e la mod costruita con `--bozza`), provate in gioco
sulla build 40420 (08-09.10.2026). La v14 (`v14-bozza-32c86032`) si carica in gioco e risponde alle azioni del
middleware (collaudo del 09.10.2026); la console con Claude non e' ancora stata provata con la v14:

| Tool | Cosa fa | Stato |
|---|---|---|
| `build_intercity_bus` | Bus tra citta' vicine | Provato (collaudo ok) |
| `add_vehicles`, `remove_vehicles`, `replace_vehicles` | Veicoli di una linea | Provati |
| `extend_line` | Allunga una linea su strada fino a un'altra citta' | Provato (build 40420) |
| `check_line_fleet`, `adjust_line_fleet` | Veicoli necessari per un passaggio ogni N secondi (solo su richiesta) | Provati |
| `connect_industry_to_city` | Usa la stazione per camion INTEGRATA dell'industria (novita' TF3) | Provato |
| `build_cargo_rail_line` | Treno merci industria -> industria (scalo vicino alla stazione integrata) | Provato (collaudo ok) |
| `build_cargo_rail_network` | Rete merci, binari d'attesa se c'e' spazio (altrimenti 1 treno, con avviso) | Provato (collaudo ok) |
| `build_rail_ring` | Anello ferroviario a binario unico (incrocio nelle stazioni); `double_track` ancora instabile | Binario unico provato |
| `build_air_or_water_line` | Aerei ed elicotteri provati; navi: porto rifiutato (molo da copiare da un porto fatto a mano) | Parziale |
| Segnali (interni) | Segnali di percorso a senso unico e a doppio senso sui binari | Provati |

Ogni azione che costruisce o compra chiede conferma prima di essere inviata.

## Requisiti

Il progetto e' pensato **solo per Windows con Steam** (percorsi, file `.bat`, `setx`):

- Transport Fever 3 (versione Steam, provato con le build 40408 e 40420), partita in modalita' creativa consigliata;
- Python 3.10+ con il pacchetto `anthropic`;
- una chiave API Anthropic (variabile d'ambiente `ANTHROPIC_API_KEY`);
- modello: configurabile in `middleware/main.py` (`MODEL`); oggi `claude-sonnet-5-5`. Il costo medio di una
  sessione non e' ancora stato misurato: verra' indicato qui dopo le prove con la v14.

## Installazione

1. Copia `mod/tfcapocantiere_1` in `C:\Program Files (x86)\Steam\userdata\<id>\3493540\local\mods\`
   e attiva la mod nella partita.
2. Python 3.10+, poi `pip install anthropic`.
3. Chiave API **solo** come variabile d'ambiente (mai nei file):
   `setx ANTHROPIC_API_KEY "..."` e riapri il terminale.
4. Controllo: `python middleware/verifica_installazione.py` (non modifica nulla).
5. Con la partita aperta: doppio clic su `middleware/avvia_capocantiere.bat`
   (oppure `python middleware/main.py`). La cartella di scambio viene trovata da sola nei dati utente di Steam;
   se non la trova: variabile `CAPOCANTIERE_DIR`.

Comandi della console: `/stato`, `/ping`, `/reset`, `/esci`.

## Note

- La mod scrive solo file `capocantiere_*.lua` nella cartella `mod_presets` dei dati utente: dalla build 40420
  (08.10.2026) il gioco permette agli script solo le proprie cartelle. Il middleware tiene registro, diario e
  collaudi nella cartella `capocantiere` dei dati utente.
- La mod nel repo ha `DEV_MODE = false`: `lua_eval` / `sim_eval` (codice arbitrario, solo per le prove) sono spenti.
  Per lo sviluppo: `python dev-notes/build_script.py --dev` crea una copia con `DEV_MODE = true`;
  `--release` crea la versione da distribuire (`dist/`, zip).
- Modello Anthropic: predefinito in `middleware/main.py` (`MODEL`), oppure variabile d'ambiente `CAPOCANTIERE_MODEL`.
  A ogni risposta il middleware stampa i token usati nella sessione (avviso oltre `CAPOCANTIERE_TOKEN_WARN`). Il middleware usa il prompt caching e tiene
  in memoria solo gli ultimi turni della conversazione (`MAX_TURNS`) per contenere i costi.
- Gli argomenti dei tool vengono controllati in Python prima di arrivare al gioco.
- All'avvio i file `actions_*` rimasti da sessioni precedenti vengono spostati in `capocantiere/vecchi`.

## Sviluppo

- `python middleware/test_middleware.py`: test del middleware senza gioco e senza API.
- `python dev-notes/build_script.py`: copia `dev-notes/cc_lib.lua` + `dev-notes/cc_actions.lua` nello script della mod
  (con backup e controllo di sintassi); `--check` verifica soltanto che siano allineati.
- `dev-notes/bozza/`: funzioni nuove ancora da provare in gioco (treni merci, bus tra citta', gestione veicoli, annulla,
  aerei/elicotteri/navi, superstrade); test senza gioco con `python3 dev-notes/bozza/run_mock.py`.
- `dev-notes/sonde/` e `dev-notes/prove/`: codice da eseguire in gioco con `python dev-notes/mkeval.py` (vedi `dev-notes/note/piano-stasera.md`).

## Licenza

MIT, vedi [LICENSE](LICENSE).

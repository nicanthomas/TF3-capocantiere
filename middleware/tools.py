"""
Schemi dei tool (JSON Schema) che Claude puo' chiamare.

Due famiglie:
  - tool LOCALI (solo lettura, eseguiti in Python sullo state.lua): find_entity, get_overview
  - tool di GIOCO (costruiscono o comprano): diventano azioni in actions.lua e richiedono
    SEMPRE la conferma dell'utente prima di essere inviati, perche' spendono soldi in gioco.

I nomi dei campi "type" delle azioni sono quelli che la mod Lua riconosce (handlers in
capocantiere.script.lua). Le azioni non ancora implementate nella mod rispondono con
"azione sconosciuta": il middleware lo riporta a Claude senza bloccarsi.
"""

LOCAL_TOOLS = {"find_entity", "get_overview"}

# Tool che spendono soldi -> chiedono conferma all'utente
SPENDING_TOOLS = {"build_station", "build_line", "build_bus_line", "build_tram_line", "build_rail_line",
                  "buy_and_assign_vehicles", "connect_industry_to_city"}

TOOLS = [
    {
        "name": "find_entity",
        "description": (
            "Cerca citta', industrie, stazioni, linee o depositi per nome (ricerca tollerante: "
            "maiuscole e accenti ignorati, basta una parte del nome). Usalo SEMPRE per trasformare "
            "un nome detto dall'utente in un id prima di usare un tool di costruzione. Restituisce "
            "id, nome, posizione (metri, x/y) e dati utili (merci, citta' di appartenenza...)."),
        "input_schema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Nome o parte del nome da cercare."},
                "kind": {
                    "type": "string",
                    "enum": ["any", "town", "industry", "station", "line", "depot"],
                    "description": "Tipo di entita' (default any).",
                },
            },
            "required": ["query"],
        },
    },
    {
        "name": "get_overview",
        "description": (
            "Riassunto aggiornato della mappa: anno, soldi, citta', industrie (con merci in entrata/uscita "
            "e citta' piu' vicina), stazioni e depositi del giocatore, linee esistenti."),
        "input_schema": {"type": "object", "properties": {}},
    },
    {
        "name": "build_bus_line",
        "description": (
            "Costruisce una linea bus completa dentro una citta': fermate sulle strade esistenti (la prima "
            "vicino al centro, le altre ad anello attorno), un deposito se non ce n'e' uno raggiungibile, "
            "la linea e i veicoli (il modello piu' recente disponibile). E' il modo piu' semplice e "
            "affidabile per servire una citta'. Chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "town_id": {"type": "integer", "description": "Id della citta' (da find_entity)."},
                "num_stops": {"type": "integer", "minimum": 2, "maximum": 8, "default": 4},
                "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 10, "default": 2},
                "name": {"type": "string"},
            },
            "required": ["town_id"],
        },
    },
    {
        "name": "build_station",
        "description": (
            "Costruisce UNA fermata vicino a un'entita' (di solito una citta'), su una strada esistente. "
            "Per ora e' supportato solo kind=bus_stop; gli altri tipi rispondono 'non ancora supportato'. "
            "Restituisce station_id da usare in build_line. Chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "kind": {
                    "type": "string",
                    "enum": ["bus_stop", "tram_stop", "truck_station", "train_station", "cargo_train_station"],
                },
                "near_entity_id": {"type": "integer", "description": "Id di citta' o industria (da find_entity)."},
                "name": {"type": "string", "description": "Nome opzionale della stazione."},
            },
            "required": ["kind", "near_entity_id"],
        },
    },
    {
        "name": "build_line",
        "description": (
            "Crea una linea che collega, in ordine, stazioni ESISTENTI (id di gruppi di stazioni). "
            "Non costruisce binari o strade. Costa denaro solo per i veicoli, ma chiede comunque conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "station_ids": {
                    "type": "array", "items": {"type": "integer"}, "minItems": 2,
                    "description": "Id dei gruppi di stazioni nell'ordine delle fermate.",
                },
                "transport": {"type": "string", "enum": ["bus", "tram", "truck", "train", "ship", "plane"]},
            },
            "required": ["name", "station_ids", "transport"],
        },
    },
    {
        "name": "build_tram_line",
        "description": (
            "Linea tram completa in una citta': fermate sulle strade, binari tram aggiunti alle strade del "
            "percorso (senza demolire edifici), deposito tram, linea e tram. I tram non fanno inversione: la "
            "mod sceglie l'anello di fermate piu' lungo percorribile e scarta le altre (lo dice nel log). "
            "Nelle citta' con strade molto strette puo' fallire: in quel caso proponi build_bus_line. "
            "Chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "town_id": {"type": "integer"},
                "num_stops": {"type": "integer", "minimum": 2, "maximum": 12, "default": 4},
                "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 10, "default": 2},
                "name": {"type": "string"},
            },
            "required": ["town_id"],
        },
    },
    {
        "name": "build_rail_line",
        "description": (
            "Linea ferroviaria passeggeri che collega 2 o piu' citta' nell'ordine dato: una stazione per "
            "citta' (fuori dal centro, binario singolo, 160 m), binari tra le stazioni con passaggi a livello "
            "sulle strade (o sovrappassi/sottopassi dove serve), ponti su acqua e valli, gallerie nelle colline, aggira "
            "industrie ed edifici, deposito treni, linea e treni (locomotiva + "
            "carrozze adatte all'anno). Binari, stazioni ed elettrificazione si adattano all'epoca. Se fallisce annulla "
            "quello che ha costruito e lo dice nel campo error. Chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "town_ids": {"type": "array", "items": {"type": "integer"}, "minItems": 2, "maxItems": 6,
                             "description": "Citta' da collegare, nell'ordine del percorso."},
                "num_trains": {"type": "integer", "minimum": 1, "maximum": 6, "default": 1,
                               "description": "Binario unico con incroci nelle stazioni (2 binari): al massimo un treno per stazione."},
                "num_cars": {"type": "integer", "minimum": 1, "maximum": 8, "default": 3,
                             "description": "Carrozze per treno."},
                "name": {"type": "string"},
            },
            "required": ["town_ids"],
        },
    },
    {
        "name": "buy_and_assign_vehicles",
        "description": (
            "Compra veicoli in un deposito e li assegna a una linea esistente. "
            "Se depot_id manca, la mod usa il deposito stradale raggiungibile piu' vicino alla prima fermata "
            "o ne costruisce uno; se model manca sceglie il bus (o camion, per stazioni merci) piu' recente. "
            "Costa denaro: chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "line_id": {"type": "integer"},
                "count": {"type": "integer", "minimum": 1, "maximum": 20},
                "depot_id": {"type": "integer"},
                "model": {"type": "string", "description": "Nome file del modello (opzionale)."},
            },
            "required": ["line_id", "count"],
        },
    },
    {
        "name": "connect_industry_to_city",
        "description": (
            "Trasporto merci su strada (camion/carri) da un'industria a un'altra industria che usa le sue "
            "merci, oppure a una citta'. Usa la stazione camion gia' presente nell'industria; per una citta' "
            "costruisce una fermata vicino al centro. Le citta' accettano solo alcune merci (vedi "
            "townAcceptedCargo in get_overview): materie prime come tronchi o cereali vanno portate a "
            "un'industria. Crea deposito (se serve), linea e veicoli adatti alla merce. Solo transport=truck "
            "per ora. Chiede conferma."),
        "input_schema": {
            "type": "object",
            "properties": {
                "industry_id": {"type": "integer"},
                "target_id": {"type": "integer", "description": "Id della citta' o industria di destinazione."},
                "transport": {"type": "string", "enum": ["truck", "train"], "default": "truck"},
                "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 20, "default": 2},
            },
            "required": ["industry_id", "target_id"],
        },
    },
]


def describe_action(name: str, args: dict, state: dict) -> str:
    """Descrizione leggibile di un'azione, da mostrare all'utente prima della conferma."""
    names = {}
    for key in ("towns", "industries", "stations", "lines", "depots"):
        for it in state.get(key, []):
            names[it["id"]] = it.get("name", str(it["id"]))

    def n(i):
        return f"{names.get(i, '?')} (id {i})"

    if name == "build_station":
        return f"Costruire {args['kind']} vicino a {n(args['near_entity_id'])}"
    if name == "build_line":
        stops = " -> ".join(n(i) for i in args["station_ids"])
        return f"Creare la linea {args['transport']} '{args['name']}': {stops}"
    if name == "build_bus_line":
        return (f"Linea bus completa a {n(args['town_id'])}: {args.get('num_stops', 4)} fermate, "
                f"{args.get('num_vehicles', 2)} veicoli, deposito se serve")
    if name == "build_tram_line":
        return (f"Linea tram completa a {n(args['town_id'])}: {args.get('num_stops', 4)} fermate, "
                f"{args.get('num_vehicles', 2)} veicoli")
    if name == "build_rail_line":
        towns = " - ".join(n(i) for i in args["town_ids"])
        return (f"Ferrovia {towns}: stazioni, binari, deposito e {args.get('num_trains', 1)} treni "
                f"da {args.get('num_cars', 3)} carrozze")
    if name == "buy_and_assign_vehicles":
        return f"Comprare {args['count']} veicoli per la linea {n(args['line_id'])}"
    if name == "connect_industry_to_city":
        return (f"Collegare {n(args['industry_id'])} a {n(args['target_id'])} "
                f"via {args.get('transport', 'truck')} con {args.get('num_vehicles', 2)} veicoli")
    return f"{name} {args}"

"""
Tool per le azioni della BOZZA (dev/bozza, NON ANCORA PROVATE IN GIOCO).

Si attivano solo con la variabile d'ambiente CAPOCANTIERE_BOZZA=1 e con la mod costruita includendo la bozza:
senza, Claude non li vede. Quando un'azione e' provata in gioco, il suo schema si sposta in tools.py.
"""

from __future__ import annotations

SPENDING_TOOLS_BOZZA = {
    "build_intercity_bus", "connect_station_to_town", "add_vehicles", "remove_vehicles", "replace_vehicles",
    "delete_line", "extend_line", "build_cargo_rail_line", "build_air_or_water_line", "build_highway",
    "undo_last_action",
}

_ID = {"type": "integer"}

TOOLS_BOZZA = [
    {
        "name": "build_intercity_bus",
        "description": "Linea bus tra 2 o piu' citta' vicine (riusa le fermate gia' presenti in centro). Chiede conferma.",
        "input_schema": {"type": "object", "properties": {
            "town_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 6},
            "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 10, "default": 2},
            "name": {"type": "string"}}, "required": ["town_ids"]},
    },
    {
        "name": "connect_station_to_town",
        "description": ("Nodo di scambio: fermata bus accanto a una stazione (treno, porto, aeroporto) e navetta bus fino al "
                        "centro della citta'. Usalo dopo una ferrovia se la stazione e' lontana dal centro. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "station_id": {"type": "integer", "description": "Id del gruppo di stazioni."},
            "town_id": {"type": "integer"},
            "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 6, "default": 2}}, "required": ["station_id"]},
    },
    {
        "name": "add_vehicles",
        "description": "Aggiunge a una linea veicoli uguali a quelli che ha gia' (bus, tram, camion, treni). Chiede conferma.",
        "input_schema": {"type": "object", "properties": {
            "line_id": _ID, "count": {"type": "integer", "minimum": 1, "maximum": 20}}, "required": ["line_id", "count"]},
    },
    {
        "name": "remove_vehicles",
        "description": "Vende veicoli di una linea (ne resta sempre almeno uno). Chiede conferma.",
        "input_schema": {"type": "object", "properties": {
            "line_id": _ID, "count": {"type": "integer", "minimum": 1, "maximum": 50}}, "required": ["line_id", "count"]},
    },
    {
        "name": "replace_vehicles",
        "description": "Sostituisce i veicoli di una linea con i modelli piu' recenti disponibili. Chiede conferma.",
        "input_schema": {"type": "object", "properties": {"line_id": _ID}, "required": ["line_id"]},
    },
    {
        "name": "delete_line",
        "description": "Cancella una linea e vende i suoi veicoli (le stazioni restano). Chiede conferma.",
        "input_schema": {"type": "object", "properties": {"line_id": _ID}, "required": ["line_id"]},
    },
    {
        "name": "extend_line",
        "description": "Allunga una linea su strada (bus, tram, camion) con una fermata in un'altra citta'. Chiede conferma.",
        "input_schema": {"type": "object", "properties": {"line_id": _ID, "town_id": _ID}, "required": ["line_id", "town_id"]},
    },
    {
        "name": "build_cargo_rail_line",
        "description": ("Treno merci da un'industria a un'industria che usa la sua merce (o a una citta' che la accetta): "
                        "scali merci con l'industria nel bacino, binari, deposito, linea e treni. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "industry_id": _ID, "target_id": _ID,
            "num_trains": {"type": "integer", "minimum": 1, "maximum": 2, "default": 1},
            "num_cars": {"type": "integer", "minimum": 1, "maximum": 10, "default": 4},
            "name": {"type": "string"}}, "required": ["industry_id", "target_id"]},
    },
    {
        "name": "build_air_or_water_line",
        "description": ("Linea aerea, di elicotteri o di navi tra citta': kind = airfield | airport | heliport | harbor. "
                        "cargo=true per le merci. Funziona solo per i tipi gia' configurati nella mod. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "town_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 4},
            "kind": {"type": "string", "enum": ["airfield", "airport", "heliport", "harbor"]},
            "cargo": {"type": "boolean", "default": False},
            "num_vehicles": {"type": "integer", "minimum": 1, "maximum": 10, "default": 2},
            "name": {"type": "string"}}, "required": ["town_ids", "kind"]},
    },
    {
        "name": "build_highway",
        "description": ("Superstrada tra 2 citta' con ponti, gallerie e incroci tutti a livelli separati (senza svincoli: "
                        "si collega a una strada ai margini di ogni citta'). Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "town_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 2}}, "required": ["town_ids"]},
    },
    {
        "name": "undo_last_action",
        "description": ("Annulla l'ultima azione che ha costruito qualcosa: vende i veicoli, cancella le linee, toglie "
                        "stazioni, depositi e binari creati. Le strade cittadine modificate restano. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {}},
    },
]

SYSTEM_PROMPT_BOZZA = """
Azioni in prova (bozza): build_intercity_bus, connect_station_to_town, add_vehicles, remove_vehicles, replace_vehicles,
delete_line, extend_line, build_cargo_rail_line, build_air_or_water_line, build_highway, undo_last_action.
Sono nuove: se una fallisce riporta l'errore esatto all'utente. Dopo una ferrovia passeggeri, se la stazione e' lontana
dal centro, proponi connect_station_to_town per creare il nodo di scambio con il bus.
"""


def describe_bozza(name: str, args: dict, n) -> str | None:
    if name == "build_intercity_bus":
        return "Bus tra " + " - ".join(n(i) for i in args["town_ids"]) + f" con {args.get('num_vehicles', 2)} veicoli"
    if name == "connect_station_to_town":
        return f"Navetta bus dalla stazione {n(args['station_id'])} al centro"
    if name == "add_vehicles":
        return f"Aggiungere {args['count']} veicoli alla linea {n(args['line_id'])}"
    if name == "remove_vehicles":
        return f"Vendere {args['count']} veicoli della linea {n(args['line_id'])}"
    if name == "replace_vehicles":
        return f"Sostituire i veicoli della linea {n(args['line_id'])} con modelli recenti"
    if name == "delete_line":
        return f"CANCELLARE la linea {n(args['line_id'])} e vendere i suoi veicoli"
    if name == "extend_line":
        return f"Allungare la linea {n(args['line_id'])} fino a {n(args['town_id'])}"
    if name == "build_cargo_rail_line":
        return (f"Treno merci da {n(args['industry_id'])} a {n(args['target_id'])}: scali, binari, deposito, "
                f"{args.get('num_trains', 1)} treni da {args.get('num_cars', 4)} carri")
    if name == "build_air_or_water_line":
        return f"Linea {args['kind']} tra " + " - ".join(n(i) for i in args["town_ids"]) + (" (merci)" if args.get("cargo") else "")
    if name == "build_highway":
        return "Superstrada tra " + " e ".join(n(i) for i in args["town_ids"])
    if name == "undo_last_action":
        return "ANNULLARE l'ultima azione (vendita veicoli, rimozione di linee, stazioni, depositi e binari creati)"
    return None

"""
Tool per le azioni della BOZZA (dev-notes/bozza, NON ANCORA PROVATE IN GIOCO).

Si attivano solo con la variabile d'ambiente CAPOCANTIERE_BOZZA=1 e con la mod costruita includendo la bozza:
senza, Claude non li vede. Quando un'azione e' provata in gioco, il suo schema si sposta in tools.py.
"""

from __future__ import annotations

SPENDING_TOOLS_BOZZA = {
    "build_intercity_bus", "connect_station_to_town", "add_vehicles", "remove_vehicles", "replace_vehicles",
    "delete_line", "extend_line", "build_cargo_rail_line", "build_air_or_water_line", "build_highway",
    "undo_last_action",
    "build_depot", "build_rail_line2", "build_rail_ring", "build_cargo_rail_network", "create_line_from_stations",
    "build_rail_station", "adjust_line_fleet",
}

# Tool della bozza che leggono soltanto (nessuna conferma): vanno comunque al gioco.
READ_TOOLS_BOZZA = {"check_line", "check_network", "read_map", "check_line_fleet"}

# Tool gestiti dal middleware senza il gioco.
LOCAL_TOOLS_BOZZA = {"propose_plan"}

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
            "kind": {"type": "string", "enum": ["airfield", "airport", "heliport", "helipad", "harbor", "harbor_large"]},
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
        "name": "build_depot",
        "description": ("Costruisce un deposito (kind = road | tram | rail | water) vicino a una stazione (station_id) o a una "
                        "citta' (town_id), verso l'esterno del centro, collegato alla rete. Usalo quando check_line dice che "
                        "nessun deposito raggiunge la linea. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "kind": {"type": "string", "enum": ["road", "tram", "rail", "water"]},
            "station_id": _ID, "town_id": _ID, "name": {"type": "string"}}, "required": ["kind"]},
    },
    {
        "name": "build_rail_line2",
        "description": ("Ferrovia passeggeri tra 2-6 citta' (in ordine di percorso) con stazioni nel punto con piu' edifici e "
                        "dimensionate (lunghezza e binari in base ai treni), navette verso il centro. double_track = doppio "
                        "binario con segnali; express_town_ids = linea veloce che ferma solo in quelle citta' (binari di "
                        "transito nelle altre). I treni fermano anche al ritorno. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "town_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 6},
            "num_trains": {"type": "integer", "minimum": 1, "maximum": 12, "default": 1},
            "num_cars": {"type": "integer", "minimum": 1, "maximum": 12, "default": 3},
            "double_track": {"type": "boolean", "default": False},
            "express_town_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 6},
            "express_trains": {"type": "integer", "minimum": 1, "maximum": 4, "default": 1},
            "feeder": {"type": "boolean", "default": True},
            "name": {"type": "string"}}, "required": ["town_ids"]},
    },
    {
        "name": "build_rail_ring",
        "description": ("Ferrovia ad anello tra 3-8 citta' (ordinate per il giro piu' corto, salvo reorder=false), linee nei "
                        "due sensi (both_directions), treni distribuiti lungo il giro, deposito accanto alla prima stazione. "
                        "double_track = un binario per senso con segnali. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "town_ids": {"type": "array", "items": _ID, "minItems": 3, "maxItems": 8},
            "both_directions": {"type": "boolean", "default": True},
            "trains_per_direction": {"type": "integer", "minimum": 1, "maximum": 4, "default": 1},
            "num_cars": {"type": "integer", "minimum": 1, "maximum": 12, "default": 3},
            "double_track": {"type": "boolean", "default": False},
            "reorder": {"type": "boolean", "default": True},
            "name": {"type": "string"}}, "required": ["town_ids"]},
    },
    {
        "name": "build_cargo_rail_network",
        "description": ("Linea merci in treno a piu' fermate: raccolta da piu' industrie (pickup_ids), consegna a piu' "
                        "industrie o citta' (delivery_ids), carico anche al ritorno (return_cargo), vagoni per tutte le merci, "
                        "scali dimensionati, binari d'attesa se i treni sono piu' dei binari. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "pickup_ids": {"type": "array", "items": _ID, "minItems": 1, "maxItems": 5},
            "delivery_ids": {"type": "array", "items": _ID, "minItems": 1, "maxItems": 5},
            "num_trains": {"type": "integer", "minimum": 1, "maximum": 6, "default": 1},
            "num_cars": {"type": "integer", "minimum": 1, "maximum": 16, "default": 6},
            "return_cargo": {"type": "boolean", "default": True},
            "name": {"type": "string"}}, "required": ["pickup_ids", "delivery_ids"]},
    },
    {
        "name": "create_line_from_stations",
        "description": ("Linea su stazioni gia' costruite (id dei gruppi, in ordine di percorso): pattern back_forth (andata e "
                        "ritorno con fermate) o ring (anello; both_directions = anche il verso opposto). vehicle auto/bus/tram/"
                        "truck/train/ship/plane; cargo = nome della merce per treni o camion merci. Serve anche per linee veloci "
                        "o merci sugli stessi binari di un'altra linea. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "station_ids": {"type": "array", "items": _ID, "minItems": 2, "maxItems": 12},
            "pattern": {"type": "string", "enum": ["back_forth", "ring"], "default": "back_forth"},
            "both_directions": {"type": "boolean", "default": False},
            "vehicle": {"type": "string", "enum": ["auto", "bus", "tram", "truck", "train", "ship", "plane"], "default": "auto"},
            "count": {"type": "integer", "minimum": 1, "maximum": 20, "default": 2},
            "num_cars": {"type": "integer", "minimum": 1, "maximum": 12, "default": 4},
            "cargo": {"type": "string"},
            "name": {"type": "string"}}, "required": ["station_ids"]},
    },
    {
        "name": "build_rail_station",
        "description": ("Una stazione ferroviaria (kind passengers | cargo) vicino a una citta' o industria (near_id), "
                        "dimensionata per trains/lines, collegata con un raccordo al binario del giocatore piu' vicino "
                        "(connect, default si'): per aggiungere scali merci o fermate a una linea esistente. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "near_id": _ID, "kind": {"type": "string", "enum": ["passengers", "cargo"], "default": "passengers"},
            "trains": {"type": "integer", "minimum": 1, "maximum": 12, "default": 1},
            "lines": {"type": "integer", "minimum": 1, "maximum": 6, "default": 1},
            "train_len": {"type": "integer", "minimum": 40, "maximum": 480},
            "connect": {"type": "boolean", "default": True},
            "name": {"type": "string"}}, "required": ["near_id"]},
    },
    {
        "name": "check_line",
        "description": ("Collaudo di una linea: percorso tra le fermate, veicoli presenti e in movimento, deposito, bacino delle "
                        "fermate, statistiche se disponibili. Restituisce problemi e suggerimenti. Non costruisce nulla."),
        "input_schema": {"type": "object", "properties": {"line_id": _ID}, "required": ["line_id"]},
    },
    {
        "name": "check_network",
        "description": "Controlla tutte le linee del giocatore e restituisce solo quelle con problemi. Non costruisce nulla.",
        "input_schema": {"type": "object", "properties": {"max_lines": {"type": "integer", "minimum": 1, "maximum": 100}}},
    },
    {
        "name": "read_map",
        "description": ("Mappa per pianificare: citta' ordinate per grandezza (edifici), industrie con merci, griglia di quote e "
                        "acqua (grid punti per lato), linee esistenti. Usalo prima di un piano per direttive ampie."),
        "input_schema": {"type": "object", "properties": {"grid": {"type": "integer", "minimum": 4, "maximum": 16, "default": 10}}},
    },
    {
        "name": "propose_plan",
        "description": ("Mostra all'utente un piano in passi (prima le arterie, poi linee secondarie e nodi di scambio) e chiede "
                        "conferma. Usalo per direttive ampie PRIMA di costruire. Risponde approved=true/false ed eventuali "
                        "modifiche chieste dall'utente (feedback)."),
        "input_schema": {"type": "object", "properties": {
            "title": {"type": "string"},
            "steps": {"type": "array", "minItems": 1, "maxItems": 20, "items": {"type": "object", "properties": {
                "action": {"type": "string"}, "description": {"type": "string"}}, "required": ["description"]}},
            "notes": {"type": "string"}}, "required": ["steps"]},
    },
    {
        "name": "check_line_fleet",
        "description": ("Controlla quanti veicoli servono a una linea: tempo di un giro misurato dai veicoli (serve che "
                        "abbiano gia' fatto un giro), passaggio attuale e numero di veicoli per un passaggio ogni "
                        "`interval` secondi (default: bus 240, camion 300, treni 480). Solo lettura: propone, non compra."),
        "input_schema": {"type": "object", "properties": {
            "line_id": _ID, "interval": {"type": "number", "minimum": 60, "maximum": 3600},
            "max": {"type": "integer", "minimum": 1, "maximum": 20}}, "required": ["line_id"]},
    },
    {
        "name": "adjust_line_fleet",
        "description": ("Come check_line_fleet, ma compra o vende la differenza. Solo se l'utente lo chiede. Treni: non "
                        "aggiunge da solo (binario unico) salvo force=true. Chiede conferma."),
        "input_schema": {"type": "object", "properties": {
            "line_id": _ID, "interval": {"type": "number", "minimum": 60, "maximum": 3600},
            "max": {"type": "integer", "minimum": 1, "maximum": 20}, "force": {"type": "boolean"}}, "required": ["line_id"]},
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
delete_line, extend_line, build_cargo_rail_line, build_air_or_water_line, build_highway, undo_last_action, build_depot,
build_rail_line2, build_rail_ring, build_cargo_rail_network, create_line_from_stations, build_rail_station, check_line,
check_network, read_map, propose_plan, check_line_fleet, adjust_line_fleet.
Flotta: solo su richiesta dell'utente ("adegua i veicoli della linea X"): prima check_line_fleet, poi, se l'utente
approva, adjust_line_fleet. Nessun controllo o acquisto automatico.
Sono nuove: se una fallisce riporta l'errore esatto all'utente. Dopo una ferrovia passeggeri, se la stazione e' lontana
dal centro, proponi connect_station_to_town per creare il nodo di scambio con il bus.

Come lavori (bozza):
- Direttive ampie ("collega le citta' principali", "porta il carbone a X"): read_map, poi propose_plan con passi concreti
  (arterie prima, poi linee secondarie, nodi di scambio, merci). Costruisci solo dopo approved=true, un passo alla volta,
  controllando ogni risultato (campo collaudo). Se l'utente chiede modifiche (feedback), rifai il piano.
- Tutto deve funzionare: dopo ogni costruzione leggi "collaudo" nel risultato. Se ci sono problemi, spiegali e proponi la
  correzione (build_depot, add_vehicles, connect_station_to_town...), senza farla prima della conferma.
- Binari: binario unico con stazioni d'incrocio per poco traffico (1-2 treni per senso); double_track quando i treni
  sono di piu' o ci sono piu' linee (merci, veloci) sugli stessi binari. Linee veloci: express_town_ids. Anelli:
  build_rail_ring con both_directions. Merci con piu' industrie: build_cargo_rail_network.
- Stazioni e treni: la mod le dimensiona da sola (lunghezza in base ai treni, binari in base a linee e treni). Se una
  stazione non trova spazio riporta le alternative ricevute; demolire edifici solo se l'utente lo chiede.
- Notizie [Collaudo automatico] nel messaggio dell'utente: sono controlli fatti dopo 1-2 mesi di gioco; se ci sono
  problemi proponi le correzioni.
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
    if name == "build_depot":
        where = n(args["station_id"]) if args.get("station_id") else n(args.get("town_id"))
        return f"Deposito {args['kind']} vicino a {where}"
    if name == "build_rail_line2":
        extra = []
        if args.get("double_track"):
            extra.append("doppio binario")
        if args.get("express_town_ids"):
            extra.append("linea veloce per " + ", ".join(n(i) for i in args["express_town_ids"]))
        return ("Ferrovia " + " - ".join(n(i) for i in args["town_ids"]) + f", {args.get('num_trains', 1)} treni"
                + (" (" + "; ".join(extra) + ")" if extra else ""))
    if name == "build_rail_ring":
        return ("Ferrovia ad anello " + " - ".join(n(i) for i in args["town_ids"])
                + (" nei due sensi" if args.get("both_directions", True) else "")
                + (", doppio binario" if args.get("double_track") else "")
                + f", {args.get('trains_per_direction', 1)} treni per senso")
    if name == "build_cargo_rail_network":
        return ("Treno merci: raccolta a " + ", ".join(n(i) for i in args["pickup_ids"]) + "; consegna a "
                + ", ".join(n(i) for i in args["delivery_ids"]) + f"; {args.get('num_trains', 1)} treni")
    if name == "create_line_from_stations":
        return (f"Linea {args.get('pattern', 'back_forth')} su " + " - ".join(n(i) for i in args["station_ids"])
                + f" con {args.get('count', 2)} veicoli {args.get('vehicle', 'auto')}"
                + (f" ({args['cargo']})" if args.get("cargo") else ""))
    if name == "adjust_line_fleet":
        return (f"Adeguare i veicoli della linea {n(args['line_id'])} (passaggio ogni {args.get('interval', 'standard')} s"
                + (", anche treni" if args.get("force") else "") + ")")
    if name == "build_rail_station":
        return f"Stazione {args.get('kind', 'passengers')} vicino a {n(args['near_id'])}" + (
            " collegata al binario piu' vicino" if args.get("connect", True) else "")
    return None


def format_plan(args: dict) -> str:
    """Testo del piano proposto da Claude, da mostrare all'utente."""
    lines = []
    if args.get("title"):
        lines.append(args["title"])
    for i, st in enumerate(args.get("steps", []), 1):
        act = f" [{st['action']}]" if st.get("action") else ""
        lines.append(f"  {i}. {st.get('description', '')}{act}")
    if args.get("notes"):
        lines.append("  Note: " + args["notes"])
    return "\n".join(lines)

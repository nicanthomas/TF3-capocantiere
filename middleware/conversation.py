"""
Aiuti per la conversazione con Claude:
  - validate_args: controlla gli argomenti di un tool rispetto al suo JSON Schema prima di mandarli al gioco
  - trim_history: tiene solo gli ultimi turni della conversazione (meno token = meno costi)
  - cached_request: prepara system, tools e messaggi con i punti di cache (prompt caching dell'API)
"""

from __future__ import annotations

import copy
from typing import Any

CACHE = {"type": "ephemeral"}

_TYPES = {
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "string": lambda v: isinstance(v, str),
    "boolean": lambda v: isinstance(v, bool),
    "array": lambda v: isinstance(v, list),
    "object": lambda v: isinstance(v, dict),
}


def _check(value: Any, schema: dict, path: str, errors: list[str]) -> None:
    t = schema.get("type")
    if t and not _TYPES[t](value):
        errors.append(f"{path}: atteso {t}, ricevuto {type(value).__name__}")
        return
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: valore {value!r} non ammesso (ammessi: {schema['enum']})")
    if t in ("integer", "number"):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path}: {value} sotto il minimo {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path}: {value} sopra il massimo {schema['maximum']}")
    if t == "array":
        if "minItems" in schema and len(value) < schema["minItems"]:
            errors.append(f"{path}: servono almeno {schema['minItems']} elementi")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{path}: al massimo {schema['maxItems']} elementi")
        if "items" in schema:
            for i, x in enumerate(value):
                _check(x, schema["items"], f"{path}[{i}]", errors)
    if t == "object":
        props = schema.get("properties", {})
        for req in schema.get("required", []):
            if req not in value:
                errors.append(f"{path}.{req}: mancante" if path else f"{req}: mancante")
        for k, v in value.items():
            if k in props:     # i campi in piu' vengono ignorati dalla mod: non sono un errore
                _check(v, props[k], f"{path}.{k}" if path else k, errors)


def validate_args(tool: dict, args: Any) -> list[str]:
    """Lista di errori (vuota se gli argomenti rispettano lo schema del tool)."""
    errors: list[str] = []
    _check(args if args is not None else {}, tool.get("input_schema", {"type": "object"}), "", errors)
    return errors


# ---------------------------------------------------------------------- storico

def _is_turn_start(msg: dict) -> bool:
    """Un turno inizia con un messaggio dell'utente scritto da lui (non un risultato di tool)."""
    if msg.get("role") != "user":
        return False
    c = msg.get("content")
    if isinstance(c, str):
        return True
    return isinstance(c, list) and not any(isinstance(b, dict) and b.get("type") == "tool_result" for b in c)


def trim_history(messages: list, max_turns: int = 8) -> int:
    """Tiene gli ultimi max_turns turni (taglio solo all'inizio di un turno, cosi' le coppie
    tool_use/tool_result restano intere). Modifica la lista e ritorna quanti messaggi ha tolto.
    Lo stato della partita non si perde: Claude lo rilegge con get_overview / find_entity."""
    starts = [i for i, m in enumerate(messages) if _is_turn_start(m)]
    if len(starts) <= max_turns:
        return 0
    cut = starts[-max_turns]
    del messages[:cut]
    return cut


# ---------------------------------------------------------------------- cache

def cached_request(system: str, tools: list, messages: list) -> dict:
    """Argomenti per client.messages.create con 3 punti di cache:
    fine dei tool, fine del prompt di sistema, ultimo blocco dell'ultimo messaggio.
    Non modifica gli oggetti originali."""
    tools2 = [dict(t) for t in tools]
    if tools2:
        tools2[-1]["cache_control"] = CACHE
    system2 = [{"type": "text", "text": system, "cache_control": CACHE}]
    msgs2 = list(messages)
    if msgs2:
        last = dict(msgs2[-1])
        c = last.get("content")
        if isinstance(c, str):
            last["content"] = [{"type": "text", "text": c, "cache_control": CACHE}]
        elif isinstance(c, list) and c and isinstance(c[-1], dict):
            blocks = [copy.copy(b) for b in c]
            blocks[-1] = dict(blocks[-1], cache_control=CACHE)
            last["content"] = blocks
        msgs2[-1] = last
    return {"system": system2, "tools": tools2, "messages": msgs2}

"""
Aiuti per la conversazione con Claude:
  - validate_args: controlla gli argomenti di un tool rispetto al suo JSON Schema prima di mandarli al gioco
  - trim_history: tiene solo gli ultimi turni della conversazione (meno token = meno costi)
  - summarize_history: come trim_history, ma i turni tolti diventano un riassunto (cosa e' stato costruito, id,
    decisioni, piani approvati): Claude non perde il contesto delle costruzioni fatte prima
  - cached_request: prepara system, tools e messaggi con i punti di cache (prompt caching dell'API)
"""

from __future__ import annotations

import copy
import json
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


SUMMARY_PROMPT = """Riassumi in italiano, in al massimo 15 righe, la parte di conversazione che ricevi tra un utente e il
"Capo Cantiere" di Transport Fever 3. Tieni solo cio' che serve per continuare il lavoro:
- cosa e' stato costruito, con gli id di linee, stazioni, depositi e citta' (gli id sono importanti);
- decisioni e preferenze dell'utente, piani approvati e passi non ancora fatti;
- problemi aperti (collaudi falliti, errori della mod).
Niente frasi di cortesia. Se c'e' gia' un riassunto precedente, uniscilo al nuovo."""

SUMMARY_HEAD = "[Riassunto della conversazione precedente]"


def _block_get(b: Any, key: str, default: Any = None) -> Any:
    """I blocchi possono essere dizionari (scritti da noi) o oggetti dell'SDK (risposte di Claude)."""
    if isinstance(b, dict):
        return b.get(key, default)
    return getattr(b, key, default)


def transcript(messages: list, max_chars: int = 15000, result_chars: int = 400) -> str:
    """Testo semplice della conversazione (per il riassunto): messaggi, tool chiamati e risultati accorciati."""
    out = []
    for m in messages:
        who = "Utente" if m.get("role") == "user" else "Capo Cantiere"
        c = m.get("content")
        if isinstance(c, str):
            out.append(f"{who}: {c}")
            continue
        for b in c or []:
            t = _block_get(b, "type")
            if t == "text":
                out.append(f"{who}: {_block_get(b, 'text', '')}")
            elif t == "tool_use":
                args = json.dumps(_block_get(b, "input", {}) or {}, ensure_ascii=False)
                out.append(f"[tool {_block_get(b, 'name')} {args}]")
            elif t == "tool_result":
                res = _block_get(b, "content", "")
                if not isinstance(res, str):
                    res = json.dumps(res, ensure_ascii=False)
                out.append(f"[risultato: {res[:result_chars]}]")
    text = "\n".join(out)
    return text[-max_chars:]


def summarize_history(client: Any, model: str, messages: list, max_turns: int = 8, max_tokens: int = 700) -> int:
    """Se i turni sono piu' di max_turns, sostituisce i piu' vecchi con un riassunto fatto da Claude (una coppia di
    messaggi utente/assistente all'inizio). Modifica la lista e ritorna quanti messaggi ha tolto.
    Se la chiamata fallisce l'eccezione passa al chiamante, che puo' ripiegare su trim_history."""
    starts = [i for i, m in enumerate(messages) if _is_turn_start(m)]
    if len(starts) <= max_turns:
        return 0
    cut = starts[-max_turns]
    old = messages[:cut]
    resp = client.messages.create(model=model, max_tokens=max_tokens, system=SUMMARY_PROMPT,
                                  messages=[{"role": "user", "content": transcript(old)}])
    summary = "".join(_block_get(b, "text", "") for b in resp.content if _block_get(b, "type") == "text").strip()
    if not summary:
        raise RuntimeError("riassunto vuoto")
    messages[:cut] = [{"role": "user", "content": f"{SUMMARY_HEAD}\n{summary}"},
                      {"role": "assistant", "content": "Ok, ne tengo conto."}]
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

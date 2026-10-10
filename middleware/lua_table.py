"""
Lettura e scrittura delle tabelle Lua usate da Transport Fever 3 per i file "userdata".

Il gioco (app.saveUserdata) scrive file di questo tipo:

    function data()
    return {
            lato = "gui",
            valore = 42,
            lista = { 1, 2, 3, },
            ["chiave strana"] = true,
        }
    end

e app.loadUserdata legge lo stesso formato. Questo modulo:
  - load_userdata(path)  -> converte il file in dict/list Python
  - dump_userdata(obj)   -> produce il testo Lua equivalente da scrivere su disco

Non esegue codice Lua: e' un piccolo parser che accetta solo letterali
(tabelle, stringhe, numeri, true/false/nil). Qualsiasi altra cosa genera un errore.
"""

from __future__ import annotations

import os
import re
import tempfile
import time
from typing import Any


class LuaParseError(ValueError):
    pass


# --------------------------------------------------------------------------- lettura

_TOKEN_RE = re.compile(
    r"""
    (?P<ws>\s+|--\[\[.*?\]\]|--[^\n]*)                # spazi e commenti
  | (?P<long>\[(?P<eq>=*)\[.*?\](?P=eq)\])            # stringa lunga [[...]]
  | (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')      # stringhe
  | (?P<num>-?0[xX][0-9a-fA-F]+|-?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)
  | (?P<name>[A-Za-z_][A-Za-z0-9_]*)
  | (?P<sym>[{}\[\]=,;()-])
    """,
    re.VERBOSE | re.DOTALL,
)

_ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f",
            "v": "\v", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


def _unescape(body: str) -> str:
    out = []
    i = 0
    while i < len(body):
        c = body[i]
        if c != "\\":
            out.append(c)
            i += 1
            continue
        i += 1
        if i >= len(body):
            break
        e = body[i]
        if e in _ESCAPES:
            out.append(_ESCAPES[e])
            i += 1
        elif e.isdigit():                     # \ddd decimale (byte)
            m = re.match(r"\d{1,3}", body[i:])
            out.append(chr(int(m.group(0))))
            i += len(m.group(0))
        elif e == "x":                        # \xXX
            out.append(chr(int(body[i + 1:i + 3], 16)))
            i += 3
        elif e == "z":                        # \z salta spazi
            i += 1
            while i < len(body) and body[i].isspace():
                i += 1
        else:
            out.append(e)
            i += 1
    s = "".join(out)
    # Lua lavora a byte: le stringhe UTF-8 escapate come \ddd vanno ricomposte
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return s


def _tokenize(text: str):
    pos = 0
    tokens = []
    while pos < len(text):
        m = _TOKEN_RE.match(text, pos)
        if not m:
            raise LuaParseError(f"carattere inatteso alla posizione {pos}: {text[pos:pos + 30]!r}")
        pos = m.end()
        kind = m.lastgroup
        if kind == "ws":
            continue
        if kind == "eq":
            kind = "long"
        tokens.append((kind, m.group(0)))
    return tokens


class _Parser:
    def __init__(self, tokens):
        self.t = tokens
        self.i = 0

    def peek(self, k=0):
        j = self.i + k
        return self.t[j] if j < len(self.t) else (None, None)

    def take(self, value=None):
        tok = self.peek()
        if value is not None and tok[1] != value:
            raise LuaParseError(f"atteso {value!r}, trovato {tok[1]!r}")
        self.i += 1
        return tok

    def value(self):
        kind, v = self.peek()
        if kind == "sym" and v == "{":
            return self.table()
        if kind == "sym" and v == "-":             # numero negativo separato
            self.take()
            return -self.value()
        self.take()
        if kind == "str":
            return _unescape(v[1:-1])
        if kind == "long":
            m = re.match(r"\[(=*)\[\n?(.*)\]\1\]", v, re.DOTALL)
            return m.group(2)
        if kind == "num":
            if v.lower().startswith(("0x", "-0x")):
                return int(v, 16)
            f = float(v)
            return int(f) if re.fullmatch(r"-?\d+", v) else f
        if kind == "name":
            if v == "true":
                return True
            if v == "false":
                return False
            if v == "nil":
                return None
        raise LuaParseError(f"valore non supportato: {v!r}")

    def table(self):
        self.take("{")
        arr: list = []
        dct: dict = {}
        while True:
            kind, v = self.peek()
            if kind == "sym" and v == "}":
                self.take()
                break
            if kind == "sym" and v == "[":
                self.take()
                key = self.value()
                self.take("]")
                self.take("=")
                dct[key] = self.value()
            elif kind == "name" and self.peek(1) == ("sym", "="):
                self.take()
                self.take("=")
                dct[v] = self.value()
            else:
                arr.append(self.value())
            kind, v = self.peek()
            if kind == "sym" and v in (",", ";"):
                self.take()
        # Tabella solo-array -> list; chiavi intere 1..n -> list; altrimenti dict
        if not dct:
            return arr
        if not arr and all(isinstance(k, int) for k in dct) and \
                sorted(dct) == list(range(1, len(dct) + 1)):
            return [dct[k] for k in range(1, len(dct) + 1)]
        for idx, item in enumerate(arr, start=1):
            dct.setdefault(idx, item)
        return dct


def loads(text: str) -> Any:
    """Converte il testo di un file userdata (o una tabella Lua nuda) in oggetti Python."""
    tokens = _tokenize(text)
    p = _Parser(tokens)
    # Formato "function data() return {...} end"
    if p.peek() == ("name", "function"):
        p.take()
        p.take()            # data
        p.take("(")
        p.take(")")
        p.take()            # return
        val = p.value()
        p.take()            # end
        return val
    if p.peek() == ("name", "return"):
        p.take()
    return p.value()


def load_userdata(path: str) -> Any:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()
    return loads(text)


# --------------------------------------------------------------------------- scrittura

_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if",
    "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}


def _quote(s: str) -> str:
    out = ['"']
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 32:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def _dump(v: Any, indent: int) -> str:
    pad = "\t" * indent
    if v is None:
        return "nil"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if v != v or v in (float("inf"), float("-inf")):
            raise ValueError("numero non valido per Lua")
        return repr(v)
    if isinstance(v, str):
        return _quote(v)
    if isinstance(v, (list, tuple)):
        if not v:
            return "{ }"
        items = [f"{pad}\t{_dump(x, indent + 1)}," for x in v]
        return "{\n" + "\n".join(items) + f"\n{pad}}}"
    if isinstance(v, dict):
        if not v:
            return "{ }"
        items = []
        for k, x in v.items():
            if isinstance(k, str) and _IDENT_RE.match(k) and k not in _LUA_KEYWORDS:
                key = k
            elif isinstance(k, (int, str)):
                key = f"[{_dump(k, 0)}]"
            else:
                raise ValueError(f"chiave non supportata: {k!r}")
            items.append(f"{pad}\t{key} = {_dump(x, indent + 1)},")
        return "{\n" + "\n".join(items) + f"\n{pad}}}"
    raise ValueError(f"tipo non supportato: {type(v).__name__}")


def dumps(obj: Any) -> str:
    """Testo Lua nel formato di app.saveUserdata (leggibile da app.loadUserdata)."""
    return "function data()\nreturn " + _dump(obj, 0) + "\nend\n"


def save_userdata(path: str, obj: Any) -> None:
    """Scrittura atomica: file temporaneo nella stessa cartella e poi rinomina,
    cosi' il gioco non legge mai un file scritto a meta'."""
    text = dumps(obj)
    folder = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".tmp_", suffix=".lua", dir=folder)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        # Windows readers may briefly deny delete/rename sharing. Keep the
        # old file intact, retry only these errors, and bound waiting to 0.5 s.
        for attempt in range(26):
            try:
                os.replace(tmp, path)
                break
            except OSError as exc:
                if getattr(exc, "winerror", None) not in (5, 32, 33) or attempt == 25:
                    raise
                time.sleep(0.02)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


if __name__ == "__main__":
    sample = 'function data()\nreturn { \n\t\tlato = "gui",\n\t\ttesto = "ciao",\n\t\tvalore = 42,\n\t}\nend\n'
    print(loads(sample))
    print(dumps({"a": [1, 2.5, "x\"y"], "b": {"c": True}, 3: None}))

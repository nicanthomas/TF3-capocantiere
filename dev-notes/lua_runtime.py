"""Lua 5.3/5.4 via ctypes; nessuna installazione o ricerca nei dati del gioco.

Windows: CAPOCANTIERE_LUA_LIB deve indicare una DLL fidata con percorso
assoluto e architettura uguale a Python. Linux/macOS: ricerca di sistema.
"""
import ctypes
from ctypes.util import find_library
import os


class LuaUnavailable(RuntimeError):
    pass


class LuaError(RuntimeError):
    pass


def configure(library):
    pointer = ctypes.c_void_p
    signatures = {
        "luaL_newstate": ([], pointer),
        "luaL_openlibs": ([pointer], None),
        "luaL_loadbufferx": ([pointer, ctypes.c_char_p, ctypes.c_size_t,
                              ctypes.c_char_p, ctypes.c_char_p], ctypes.c_int),
        "lua_pcallk": ([pointer, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                        ctypes.c_ssize_t, pointer], ctypes.c_int),
        "lua_tolstring": ([pointer, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)], ctypes.c_char_p),
        "lua_close": ([pointer], None),
    }
    try:
        for name, (arguments, result) in signatures.items():
            function = getattr(library, name)
            function.argtypes = arguments
            function.restype = result
    except AttributeError as exc:
        raise LuaUnavailable("ABI Lua incompatibile: serve Lua 5.3/5.4") from exc
    return library


def load_library():
    explicit = os.environ.get("CAPOCANTIERE_LUA_LIB")
    if explicit:
        if not os.path.isabs(explicit):
            raise LuaUnavailable("CAPOCANTIERE_LUA_LIB richiede un percorso assoluto")
        candidates = [explicit]
    elif os.name == "nt":
        # Do not load an unqualified DLL from the current working directory.
        candidates = []
    else:
        candidates = [find_library(name) for name in ("lua5.4", "lua5.3", "lua54", "lua53")]
    failures = []
    for candidate in dict.fromkeys(candidates):
        if not candidate:
            continue
        try:
            return configure(ctypes.CDLL(candidate))
        except (OSError, LuaUnavailable) as exc:
            failures.append(str(exc))
    detail = "; ".join(failures)
    raise LuaUnavailable("Lua 5.3/5.4 non disponibile. Impostare CAPOCANTIERE_LUA_LIB "
                         "al percorso assoluto di una libreria fidata, stessa architettura Python. " + detail)


def run(code, *, execute=True, name="capocantiere", library=None):
    lua = configure(library) if library is not None else load_library()
    state = lua.luaL_newstate()
    if not state:
        raise MemoryError("Lua non ha allocato lo stato")
    try:
        if execute:
            lua.luaL_openlibs(state)
        source = code.encode("utf-8")
        error = lua.luaL_loadbufferx(state, source, len(source), name.encode("utf-8"), b"t")
        if not error and execute:
            error = lua.lua_pcallk(state, 0, 0, 0, 0, None)
        if error:
            message = lua.lua_tolstring(state, -1, None)
            raise LuaError(message.decode("utf-8", "replace") if message else "Errore Lua senza messaggio")
    finally:
        lua.lua_close(state)

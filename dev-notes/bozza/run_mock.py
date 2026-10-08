"""Esegue i test della bozza con un finto api (serve liblua5.x sul sistema): python3 dev-notes/bozza/run_mock.py"""
import ctypes
import glob
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEV = os.path.dirname(HERE)
parts = [os.path.join(HERE, "test_mock_pre.lua"), os.path.join(DEV, "cc_lib.lua"), os.path.join(DEV, "cc_actions.lua")]
parts += sorted(glob.glob(os.path.join(HERE, "b[0-9]_*.lua")))
parts += [os.path.join(HERE, "test_mock_casi.lua")]
code = "\n".join(open(p, encoding="utf-8").read() for p in parts)

libs = sorted(glob.glob("/usr/lib/x86_64-linux-gnu/liblua5.*.so*"))
if not libs:
    sys.exit("liblua non trovata")
lua = ctypes.CDLL(libs[-1])
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
L = lua.luaL_newstate()
lua.luaL_openlibs(L)
b = code.encode("utf-8")
r = lua.luaL_loadbufferx(L, b, len(b), b"bozza", b"t") or lua.lua_pcallk(L, 0, 0, 0, None, None)
sys.stdout.flush()
if r:
    print("ERRORE:", lua.lua_tolstring(L, -1, None).decode("utf-8", "replace"))
    sys.exit(1)

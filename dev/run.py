import ctypes,glob,sys
lib=ctypes.CDLL(glob.glob('/usr/lib/x86_64-linux-gnu/liblua5.4.so*')[0])
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_openlibs.argtypes=[ctypes.c_void_p]
lib.luaL_loadstring.argtypes=[ctypes.c_void_p,ctypes.c_char_p]
lib.lua_pcallk.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_void_p,ctypes.c_void_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]; lib.lua_tolstring.restype=ctypes.c_char_p
L=lib.luaL_newstate(); lib.luaL_openlibs(L)
code=open(sys.argv[1]).read()
r=lib.luaL_loadstring(L,code.encode()) or lib.lua_pcallk(L,0,0,0,None,None)
if r: print("ERR",lib.lua_tolstring(L,-1,None))

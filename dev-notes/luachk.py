import ctypes,sys,glob
lib=ctypes.CDLL(glob.glob('/usr/lib/x86_64-linux-gnu/liblua5.4.so*')[0])
lib.luaL_newstate.restype=ctypes.c_void_p
lib.luaL_loadbufferx.argtypes=[ctypes.c_void_p,ctypes.c_char_p,ctypes.c_size_t,ctypes.c_char_p,ctypes.c_char_p]
lib.lua_tolstring.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_void_p]; lib.lua_tolstring.restype=ctypes.c_char_p
for f in sys.argv[1:]:
    L=lib.luaL_newstate(); b=open(f,'rb').read()
    r=lib.luaL_loadbufferx(L,b,len(b),f.encode(),b"t")
    print('OK' if r==0 else 'ERR', f, '' if r==0 else lib.lua_tolstring(L,-1,None))

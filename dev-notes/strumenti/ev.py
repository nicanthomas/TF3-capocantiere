# uso: ev.py ID sonda.lua [sonda2.lua ...]  -> azione lua_eval (lato interfaccia, risultato subito nello stesso file
# results). Solo per sonde di SOLA LETTURA che usano api.engine e CC (CC.each, CC.comp...). Prefisso capocantiere_.
import sys, os, secrets, glob
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.join(ROOT,'middleware')); import lua_table
out='/mnt/user-data/outputs/cc'; os.makedirs(out,exist_ok=True)
for f in glob.glob(out+'/capocantiere_actions_*'): os.remove(f)
aid=int(sys.argv[1]); nonce=secrets.token_hex(4)
SHIM='''local CC = CC or {}
CC.each = CC.each or function(v)
	local o = {}
	if v == nil then return o end
	if pcall(function() for i = 1, v:size() do o[#o + 1] = v:at(i) end end) then return o end
	o = {}
	if type(v) == "table" then for i, x in ipairs(v) do o[i] = x end end
	return o
end
CC.comp = CC.comp or function(e, t) local ok, c = pcall(api.engine.getComponent, e, t); if ok then return c end end
'''
acts=[]
for p in sys.argv[2:]:
    code=open(os.path.join(ROOT,'dev-notes',p) if not os.path.isabs(p) else p,encoding='utf-8').read()
    acts.append({'type':'lua_eval','code':SHIM+'local ok, r = pcall(function()\n'+code+'\nend)\nif ok then return r end\nreturn "ERRORE: " .. tostring(r)'})
name=f'capocantiere_actions_{aid}_{nonce}'
lua_table.save_userdata(f'{out}/{name}.lua',{'id':aid,'nonce':nonce,'actions':acts})
print(name)

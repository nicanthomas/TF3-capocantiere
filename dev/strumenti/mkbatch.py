import glob, os, sys, secrets
import os
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT,'middleware'))
import lua_table
D=os.path.join(ROOT,'dev')
base=[D+'/cc_lib.lua',D+'/cc_actions.lua']+sorted(glob.glob(D+'/bozza/b[0-9]_*.lua'))
basecode='\n'.join(open(p,encoding='utf-8').read() for p in base)
aiuti=open(D+'/prove/_aiuti.lua',encoding='utf-8').read()
def wrap(files):
    parts=[]
    for f in files:
        k=os.path.basename(f).split('_')[0]
        body=open(f,encoding='utf-8').read()
        parts.append(f'do local ok, v = pcall(function()\n{body}\nend); __R["{k}"] = ok and v or ("ERRORE: " .. tostring(v)) end')
    return basecode+'\n'+aiuti+'\nlocal __R = {}\n'+'\n'.join(parts)+'\nreturn __R\n'
def write(out, aid, actions):
    nonce=secrets.token_hex(4); name=f'actions_{aid}_{nonce}'
    lua_table.save_userdata(os.path.join(out,name+'.lua'),{'id':aid,'nonce':nonce,'actions':actions})
    return name
if __name__=='__main__':
    out=sys.argv[1]; aid=int(sys.argv[2]); mode=sys.argv[3]
    if mode=='eval':
        groups=[g.split(',') for g in sys.argv[4:]]
        acts=[]
        for i,g in enumerate(groups):
            acts.append({'type':'sim_eval','key':f'g{aid}_{i}','code':wrap([D+'/'+x for x in g])})
        print(write(out,aid,acts), [len(a['code']) for a in acts])
    else:
        keys=sys.argv[4:]
        print(write(out,aid,[{'type':'sim_result','key':k} for k in keys]))

def mix(out, aid, keys, groups):
    acts=[{'type':'sim_result','key':k} for k in keys]
    for i,g in enumerate(groups):
        acts.append({'type':'sim_eval','key':f'g{aid}_{i}','code':wrap([D+'/'+x for x in g])})
    return write(out,aid,acts)

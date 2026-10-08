# uso: step.py ID "chiavi_risultato,..." "prova1,prova2" ["prova3"...]
import sys, glob, os, subprocess
import os
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import mkbatch
out='/mnt/user-data/outputs/cc'
for f in glob.glob(out+'/actions_*')+glob.glob(out+'/capocantiere_actions_*'): os.remove(f)
aid=int(sys.argv[1]); keys=[k for k in sys.argv[2].split(',') if k]
groups=[g.split(',') for g in sys.argv[3:]]
name=mkbatch.mix(out,aid,keys,groups)
sys.path.insert(0,os.path.join(ROOT,'middleware')); import lua_table
d=lua_table.load_userdata(f'{out}/{name}.lua')
for i,a in enumerate(d['actions']):
    if a['type']=='sim_eval':
        open(f'/tmp/chk{i}.lua','w').write(a['code'])
        r=subprocess.run(['python3',os.path.join(ROOT,'dev-notes','luachk.py'),f'/tmp/chk{i}.lua'],capture_output=True,text=True).stdout.strip()
        if not r.startswith('OK'): print('SYNTAX',r)
# build 40420: la mod legge solo mod_presets, file con prefisso capocantiere_
os.replace(f'{out}/{name}.lua', f'{out}/capocantiere_{name}.lua')
print('capocantiere_' + name, [a.get('key') for a in d['actions']])

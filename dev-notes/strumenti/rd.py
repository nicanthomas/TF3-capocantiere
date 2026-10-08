# uso: rd.py ID "chiavi" sonda_gui.lua [CC_PREFISSO_LUA]  -> un file con i sim_result delle chiavi + una sonda lua_eval
import sys, os, subprocess, glob
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.join(ROOT,'middleware')); import lua_table
H=os.path.dirname(os.path.abspath(__file__))
aid, keys, probe = sys.argv[1], sys.argv[2], sys.argv[3]
pre = sys.argv[4] if len(sys.argv)>4 else ''
n1=subprocess.run(['python3',H+'/step.py',aid,keys],capture_output=True,text=True).stdout.split()[0]
tmp='/tmp/claude-0/probe_tmp.lua'; open(tmp,'w').write(pre+'\n'+open(os.path.join(ROOT,'dev-notes',probe)).read())
src=f'/mnt/user-data/outputs/cc/{n1}.lua'; d=lua_table.load_userdata(src)
subprocess.run(['python3',H+'/ev.py','0',tmp],capture_output=True,text=True)
e=[f for f in glob.glob('/mnt/user-data/outputs/cc/capocantiere_actions_0_*')][0]
ev=lua_table.load_userdata(e); os.remove(e)
d['actions']=list(d['actions'])+list(ev['actions'])
lua_table.save_userdata(src,d); print(n1)

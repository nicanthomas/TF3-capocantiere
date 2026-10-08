import sys, json
import os
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.join(ROOT,'middleware')); import lua_table
d=lua_table.load_userdata(sys.argv[1])
for r in d['results']:
    if r.get('type')=='sim_result':
        j=r.get('job')
        if not j: print('PENDING', r); continue
        v=j.get('value')
        if not isinstance(v,dict): print('VAL',v); continue
        for k,x in v.items():
            if isinstance(x,dict):
                x={kk:vv for kk,vv in x.items() if kk!='created'}
            print(k, json.dumps(x,ensure_ascii=False)[:int(sys.argv[2]) if len(sys.argv)>2 else 1500]); print()
    else:
        print(r.get('type'), r.get('ok'), r.get('error') or r.get('queued'))

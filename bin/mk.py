import sys,os,json,secrets
sys.path.insert(0,os.path.dirname(__file__))
from linode import api
pub=open(os.path.expanduser('~/mysqlk8s/keys/k_key.pub')).read().strip()
out=[]
for n in ['mk-cp','mk-w1','mk-w2','mk-w3']:
    r=api('POST','/linode/instances',{'label':n,'region':'us-southeast','type':'g6-standard-2','image':'linode/ubuntu24.04','root_pass':secrets.token_urlsafe(24),'authorized_keys':[pub],'private_ip':True,'tags':['mysqlk8s'],'booted':True})
    out.append({'label':n,'id':r['id'],'ips':r['ipv4']})
    print(n,r['id'],r['ipv4'])
json.dump(out,open(os.path.expanduser('~/mysqlk8s/instances.json'),'w'))

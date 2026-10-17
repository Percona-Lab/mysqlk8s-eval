#!/bin/bash
# publish.sh "<commit message>" : copy scripts/results to the public repo clone, scrub IPs+secrets, leak-check, commit, push
set -e; cd ~/mysqlk8s; R=/tmp/claude-1000/-home-claude/ab613604-f292-5060-b75b-72d256b0486f/scratchpad/mysqlk8s-eval
rsync -a --exclude 'results/probe-*.log' --exclude 'results/load-*.log' --exclude '*secrets*.json' phase3/ $R/phase3/
cp scen/*.local $R/scen/; cp bin/*.sh bin/*.py $R/bin/ 2>/dev/null; cp env/*.p3 env/*.env $R/env/; cp phase2/issues/filed.txt $R/phase2/issues/filed.txt
python3 - "$R" <<'P'
import json,os,re,sys,subprocess,base64
R=sys.argv[1]; subs=[]
for i in json.load(open('instances.json')):
    lab=i['label'].upper().replace('-','_'); subs+= [(i['ips'][0],f'<{lab}_PUBIP>'),(i['ips'][1],f'<{lab}_PRIVIP>')]
for k in ['oracle_root','s3_pass','token','token_b']:
    v=open('keys/'+k).read().strip()
    if len(v)>=8: subs.append((v,'REDACTED'))
t=open('manifests/oracle-cluster.yaml').read()+open('manifests/pxc-s3secret.yaml').read()
for v in re.findall(r'(?:rootPassword|aws_secret_access_key|AWS_SECRET_ACCESS_KEY)\W+\s*"?([A-Za-z0-9+/=._-]{8,})', t): subs.append((v,'REDACTED'))
for host,cmd in [('mb-cp','kubectl -n ps get secret -o json'),('mk-cp','kubectl -n oracle get secret -o json')]:
    try:
        out=json.loads(subprocess.run(['ssh','-n','-F','ssh_config',host,cmd],capture_output=True,text=True,timeout=60).stdout)
        for it in out['items']:
            if it.get('type') in ('Opaque',None):
                for v in (it.get('data') or {}).values():
                    try: s=base64.b64decode(v).decode()
                    except Exception: continue
                    if 8<=len(s)<200 and '\n' not in s: subs.append((s,'REDACTED'))
    except Exception as e: print('warn',host,e)
old='/tmp/claude-1000/-home-claude/ab613604-f292-5060-b75b-72d256b0486f/scratchpad/subs.json'
if os.path.exists(old): subs+=[(s,'REDACTED') for s in json.load(open(old)) if not re.match(r'^[0-9.]+$',s)]
subs=sorted(set(subs),key=lambda x:-len(x[0]))
for root,_,files in os.walk(R):
    if '.git' in root: continue
    for fn in files:
        p=os.path.join(root,fn)
        try: t=open(p).read()
        except Exception: continue
        o=t
        for a,b in subs: t=t.replace(a,b)
        if t!=o: open(p,'w').write(t)
bad=[a for a,_ in subs if subprocess.run(['grep','-rlF','--exclude-dir=.git',a,R],capture_output=True).stdout]
print('subs',len(subs),'LEAKS',len(bad)); sys.exit(1 if bad else 0)
P
! grep -rlE "BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY" --exclude-dir=.git $R || { echo "PRIVATE KEY FOUND"; exit 1; }
cd $R; git add -A; git -c user.name="Peter Zaitsev" -c user.email="pz@percona.com" commit -q -m "$1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; for i in 1 2 3 4; do git push -q origin HEAD && break; sleep $((2**i)); done; git log --oneline -1

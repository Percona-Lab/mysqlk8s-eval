#!/bin/bash
# soak.sh <op> <ns> <hours> [interval_min] -> random chaos every interval; summary at end
op=$1; ns=$2; H=$3; IV=${4:-30}; cd ~/mysqlk8s; source env/$op.env; export OPENV NS=$ns RES=phase2/results; source bin/rx.sh
START=$(date +%s%3N); END=$(( $(date +%s) + H*3600 )); n=0
echo "SOAK_START $START hours=$H interval=${IV}m"
while [ $(date +%s) -lt $END ]; do
  sleep $(( IV*60 - 120 + RANDOM % 240 )); [ $(date +%s) -ge $END ] && break
  n=$((n+1)); c=$(( RANDOM % 4 )); case $c in 0) s=scen/delpod.sh;; 1) s=scen/kill9.local;; 2) s=scen/delproxy.sh;; 3) s=scen/cpu.local;; esac
  echo "## event $n $(date -u +%T) $s"; WIN=600000 WAIT=5 S=60 bin/run.sh ${op}_soak_e$n $ns $op $s 2>&1 | grep -E "DISRUPT|no failed|LOSTCHECK" | cut -c1-160
done
rx "kubectl -n $ns logs probe-$op" > phase2/results/probe-$op-soak.log
python3 - phase2/results/probe-$op-soak.log $START <<'P'
import sys
f,st=sys.argv[1],int(sys.argv[2]); ok=fail=0
for l in open(f):
    p=l.split()
    if len(p)>1 and p[0].isdigit() and int(p[0])>=st:
        if p[1]=='OK': ok+=1
        else: fail+=1
print(f"SOAK probe attempts={ok+fail} ok={ok} fail={fail} availability={100*ok/max(1,ok+fail):.3f}%")
P
awk -v t=$START '$1>=t && $2=="OK"{print $4}' phase2/results/probe-$op-soak.log | sort -u > /tmp/soak_acked_$op.txt
best=0; for p in $(rx "kubectl -n $ns get pods -l $DBSEL -o name | cut -d/ -f2"); do rx "sql $p $DBCONT 'select id from probe.t'" 2>/dev/null | sort -u > /tmp/soak_ids_$op.txt; m=$(comm -23 /tmp/soak_acked_$op.txt /tmp/soak_ids_$op.txt | wc -l); echo "member $p missing=$m"; done
echo "SOAK LOSTCHECK acked=$(wc -l < /tmp/soak_acked_$op.txt) (missing per member above; 0 on any member = no loss)"
rx "kubectl -n $ns get pods | grep -vE 'probe|load|sysb|bigprep'"; echo SOAK_DONE

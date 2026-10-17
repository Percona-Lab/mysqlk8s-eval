#!/bin/bash
# phase3.sh <op>  -> runs Phase 3 battery on an already set-up cluster (probe+load running, sbbig + sbtest loaded). Env from env/<op>.env plus env/<op>.p3 (PERF_*, VOL*, SCALE*)
op=$1; cd ~/mysqlk8s; source env/$op.env; source env/$op.p3; export OPENV NS=$P3NS RES=phase3/results PERF_PROXY PERF_DIRECT PERF_EXTRA VOLPATCH VOLPVC SCALE5 SCALE3; source bin/rx.sh
h(){ rx "kubectl -n $NS wait --for=condition=Ready pod -l $DBSEL --timeout=1200s" >/dev/null 2>&1; sleep 60; }
s(){ echo "### $1 $(date -u +%T)"; WIN=${2:-900000} bin/run.sh ${op}_p3_$1 $NS $op scen/$1.local 2>&1 | grep -vE "^ +[+]" | grep -E "PERF|DISRUPT|no failed|LOSTCHECK|LOAD|DONE|KILL|MOVED|EXPANDED|SCALED|ISOLATED|writer=|cols=|ready|NETEM|rows=|ERROR" | cut -c1-230; }
for x in ${STEPS:-perf netem_delay netem_loss flap oneway longtrx ddl ddlkill bigtrx csinodeoff volexpand scale5 ophakill}; do
  h; case $x in perf) rx "bash load.sh stop $NS" >/dev/null; s perf 3000000; rx "$LOADSTART" >/dev/null;;
    csinodeoff) s csinodeoff 2400000;; scale5) s scale5 7200000;; volexpand) s volexpand 1800000;; ddlkill) s ddlkill 1800000;;
    ophakill) rx "kubectl -n $OPNS scale deploy $OPDEP --replicas=2" >/dev/null; sleep 60; s ophakill 900000; rx "kubectl -n $OPNS scale deploy $OPDEP --replicas=1" >/dev/null;;
    *) s $x;; esac
done; echo PHASE3_DONE

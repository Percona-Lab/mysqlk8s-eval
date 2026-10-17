#!/bin/bash
OPX=${1:?op}
cd ~/mysqlk8s; source env/$OPX.env; export OPENV NS=$OPX RES=phase2/results; source bin/rx.sh
h(){ rx "kubectl -n $OPX wait --for=condition=Ready pod -l $DBSEL --timeout=900s" >/dev/null 2>&1; sleep 60; }
s(){ echo "### $1"; WIN=${2:-900000} bin/run.sh ${OPX}_$1 $OPX $OPX scen/$1.local 2>&1 | grep -vE "^ +[+]" | grep -E "DISRUPT|no failed|LOSTCHECK|LOAD|drained|node back|done|K3S|FULL|FREED|Pressure|True|False|killed process|Killed|evict" | cut -c1-200; }
h; s drain 3600000
h; s cpdown 900000
h; s diskfull 1200000
h; s oom 600000
h; s cpu 600000
echo BATCH2_DONE

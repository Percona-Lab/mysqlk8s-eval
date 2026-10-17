#!/bin/bash
cd ~/mysqlk8s; source env/mariadb.env; export OPENV NS=mariadb RES=phase2/results; source bin/rx.sh
h(){ rx "kubectl -n mariadb wait --for=condition=Ready pod -l $DBSEL --timeout=900s" >/dev/null 2>&1; sleep 60; }
s(){ echo "### $1"; WIN=${2:-900000} bin/run.sh mariadb_$1 mariadb mariadb scen/$1.local 2>&1 | grep -vE "^ +[+]" | grep -E "DISRUPT|no failed|LOSTCHECK|LOAD|drained|node back|done|K3S|FULL|FREED|Pressure|True|False|killed process|Killed|evict" | cut -c1-200; }
h; s drain 3600000
h; s cpdown 900000
h; s diskfull 1200000
h; s oom 600000
h; s cpu 600000
h; echo "UUID: $(rx 'for p in 0 1 2; do echo -n "$(sql mariadb-galera-$p mariadb "show status like \"wsrep_cluster_state_uuid\"" | cut -f2) "; done')"
echo BATCH2_DONE

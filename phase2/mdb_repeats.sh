#!/bin/bash
cd ~/mysqlk8s; source env/mariadb.env; export OPENV NS=mariadb; source bin/rx.sh; export RES=phase2/results
uuidchk(){ rx 'for p in 0 1 2; do echo -n "galera-$p $(sql mariadb-galera-$p mariadb "show status like \"wsrep_cluster_state_uuid\"" | cut -f2) "; done; echo'; }
bin/repeat.sh mariadb mariadb scen/delpod.sh 3
bin/repeat.sh mariadb mariadb scen/kill9.local 3
for i in 1 2 3; do WIN=900000 S=420 bin/repeat.sh mariadb mariadb scen/fullcrash.local 1 | sed "s/_r1/_r$i/"; mv phase2/results/mariadb_fullcrash_r1.log phase2/results/mariadb_fullcrash_rep$i.log 2>/dev/null; echo "UUID after fullcrash $i: $(uuidchk)"; done
WIN=1500000 bin/repeat.sh mariadb mariadb scen/nodeoff.local 2
echo "UUID at end: $(uuidchk)"
echo REPEATS_DONE

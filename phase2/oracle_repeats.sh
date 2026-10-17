#!/bin/bash
cd ~/mysqlk8s; source env/oracle.env; export OPENV NS=oracle RES=phase2/results; source bin/rx.sh
grchk(){ rx 'sql $(dbpod) mysql "select member_host, member_state, member_role from performance_schema.replication_group_members"' | awk '{print $1,$2,$3}' | tr '\n' ';'; }
rx 'bash load.sh start oracle mycluster.oracle sb SbPass123 50 --mysql-ssl=REQUIRED' >/dev/null
bin/repeat.sh oracle oracle scen/delpod.sh 2 | sed "s/_r/_rb/"
bin/repeat.sh oracle oracle scen/kill9.local 3
for i in 1 2 3; do WIN=900000 S=420 bin/repeat.sh oracle oracle scen/fullcrash.local 1; mv phase2/results/oracle_fullcrash_r1.log phase2/results/oracle_fullcrash_rep$i.log 2>/dev/null; echo "GR after fullcrash $i: $(grchk)"; done
WIN=1500000 bin/repeat.sh oracle oracle scen/nodeoff.local 2
echo "GR at end: $(grchk)"; echo REPEATS_DONE

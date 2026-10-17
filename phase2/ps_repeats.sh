#!/bin/bash
cd ~/mysqlk8s; source env/ps.env; export OPENV NS=ps RES=phase2/results; source bin/rx.sh
grchk(){ rx 'sql $(dbpod) mysql "select member_host, member_state, member_role from performance_schema.replication_group_members"' | awk '{print $1,$2,$3}' | tr '\n' ';'; }
rx 'bash load.sh start ps ps-cluster1-haproxy.ps sb SbPass123 50 --mysql-ssl=REQUIRED' >/dev/null
bin/repeat.sh ps ps scen/delpod.sh 3
bin/repeat.sh ps ps scen/kill9.local 3
for i in 1 2 3; do WIN=900000 S=420 bin/repeat.sh ps ps scen/fullcrash.local 1; mv phase2/results/ps_fullcrash_r1.log phase2/results/ps_fullcrash_rep$i.log 2>/dev/null; echo "GR after fullcrash $i: $(grchk)"; done
WIN=1500000 bin/repeat.sh ps ps scen/nodeoff.local 2
echo "GR at end: $(grchk)"; echo REPEATS_DONE

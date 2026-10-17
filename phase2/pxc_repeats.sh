#!/bin/bash
cd ~/mysqlk8s; source env/pxc.env; export OPENV NS=pxc RES=phase2/results; source bin/rx.sh
grchk(){ rx 'for p in 0 1 2; do echo -n "$(sql cluster1-pxc-$p pxc "show status where variable_name in (\"wsrep_cluster_state_uuid\",\"wsrep_cluster_size\")" | tr "\n\t" "  ") ; "; done'; }
rx 'bash load.sh start pxc cluster1-haproxy.pxc sb SbPass123 50 --mysql-ssl=REQUIRED' >/dev/null
bin/repeat.sh pxc pxc scen/delpod.sh 3
bin/repeat.sh pxc pxc scen/kill9.local 3
for i in 1 2 3; do WIN=900000 S=420 bin/repeat.sh pxc pxc scen/fullcrash.local 1; mv phase2/results/pxc_fullcrash_r1.log phase2/results/pxc_fullcrash_rep$i.log 2>/dev/null; echo "GR after fullcrash $i: $(grchk)"; done
WIN=1500000 bin/repeat.sh pxc pxc scen/nodeoff.local 2
echo "GR at end: $(grchk)"; echo REPEATS_DONE

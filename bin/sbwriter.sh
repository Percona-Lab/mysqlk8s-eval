#!/bin/bash
# sbwriter.sh <container-name> <cli> <rootpass> <iters> : local-socket write attempts on this node's DB every 2s
for i in $(seq 1 $4); do t=$(date +%s%3N); C=$(k3s crictl ps --name "^$1\$" -q | head -1)
 r=$(timeout 4 k3s crictl exec $C $2 -uroot -p"$3" -NBe "insert into probe.t(ts,src) values (now(6),'isolated'); select 'WROTE'" 2>&1 | grep -v 'Using a pass' | tr '\n' ' ')
 echo "$t cont=${C:0:8} ${r:0:200}"; sleep 2; done

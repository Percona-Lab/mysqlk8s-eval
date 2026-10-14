# helpers sourced on mk-cp; NS set by caller
OP=${OP:-pxc}
rp(){ case $OP in pxc) kubectl -n $NS get secret cluster1-secrets -o jsonpath={.data.root}|base64 -d;; ps) kubectl -n $NS get secret ps-cluster1-secrets -o jsonpath={.data.root}|base64 -d;; oracle) echo "$(cat /root/oracle_root)";; mariadb) kubectl -n $NS get secret mariadb-root -o jsonpath={.data.password}|base64 -d;; esac; }
# sql <pod> <container> "<sql>"
sql(){ kubectl -n $NS exec $1 -c $2 -- ${CLI:-mysql} -uroot -p"$(rp)" -NBe "$3" 2>&1 | grep -v 'Using a password'; }
# writer host from last probe OK line
writer(){ kubectl -n $NS logs --tail=30 probe-$OP 2>/dev/null | awk '$2=="OK"{h=$3} END{print h}'; }
nodeof(){ kubectl -n $NS get pod $1 -o jsonpath={.spec.nodeName}; }
lostcheck(){ local n=$(echo "$1" | tr "," "\n" | wc -l) best=0 g; for p in $(kubectl -n $NS get pods -l $DBSEL -o name | cut -d/ -f2); do g=$(sql $p $DBCONT "select count(*) from probe.t where id in ($1)" 2>/dev/null | tail -1); [[ "$g" =~ ^[0-9]+$ ]] && [ $g -gt $best ] && best=$g; done; echo "LOSTCHECK acked=$n present=$best lost=$((n-best)) (max over members)"; }
dbpod(){ kubectl -n $NS get pods -l $DBSEL -o name | head -1 | cut -d/ -f2; }
isocount(){ sql $(dbpod) $DBCONT "select count(*) from probe.t where src='isolated'"; }
isoclean(){ sql $(dbpod) $DBCONT "delete from probe.t where src='isolated'"; }

RP=$(kubectl -n ps get secret ps-dr-secrets -o jsonpath={.data.root}|base64 -d)
ro(){ kubectl -n ps exec $1 -c mysql -- mysql -uroot -p"$RP" -NBe "select @@super_read_only" 2>/dev/null; }
bash mkprobe.sh psrep ps ps-rep-haproxy.ps probe ProbePass123 percona/percona-server:8.4 >/dev/null; sleep 20
echo "== planned switchover to psrep $(date +%s%3N)"; kubectl -n ps patch ps-clusterset ps-dr --type=merge -p '{"spec":{"primaryCluster":"psrep"}}'; T0=$(date +%s)
until [ "$(ro ps-rep-mysql-0)" = 0 ]; do sleep 2; [ $(( $(date +%s)-T0 )) -gt 600 ] && break; done; echo "SWITCHOVER: psrep writable after $(( $(date +%s)-T0 ))s; ps-src-mysql-0 super_read_only=$(ro ps-src-mysql-0)"
sleep 60; kubectl -n ps get ps-clusterset ps-dr -o jsonpath='{.status.clusters}'; echo
echo "== forced failover: stop psrep site, promote pssrc $(date +%s%3N)"; kubectl -n ps patch ps ps-rep --type=merge -p '{"spec":{"pause":true}}'
until [ -z "$(kubectl -n ps get pods -l app.kubernetes.io/instance=ps-rep,app.kubernetes.io/component=database -o name)" ]; do sleep 5; done; echo "PSREP_STOPPED $(date +%s%3N)"
kubectl -n ps patch ps-clusterset ps-dr --type=merge -p '{"spec":{"primaryCluster":"pssrc","unsafeFlags":{"forcedFailover":true}}}'; T1=$(date +%s)
P=$(kubectl -n ps get pods -l app.kubernetes.io/instance=ps-src,app.kubernetes.io/component=database -o name | head -1 | cut -d/ -f2)
until [ "$(ro ps-src-mysql-0)" = 0 ] || [ "$(ro ps-src-mysql-1)" = 0 ] || [ "$(ro ps-src-mysql-2)" = 0 ]; do sleep 3; [ $(( $(date +%s)-T1 )) -gt 900 ] && break; done; echo "FORCED_FAILOVER: pssrc writable after $(( $(date +%s)-T1 ))s"
sleep 30; kubectl -n ps get ps-clusterset ps-dr -o jsonpath='{.status.clusters}'; echo; kubectl -n ps logs probe-psdr --tail=1

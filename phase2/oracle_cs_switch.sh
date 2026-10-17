RP=$(cat /root/oracle_root); ro(){ kubectl -n oracle exec $1 -c mysql -- mysql -uroot -p$RP -NBe "select @@super_read_only" 2>/dev/null; }
echo "== switchover to oc2 $(date +%s%3N)"
cat <<Y | kubectl -n oracle apply -f -
apiVersion: mysql.oracle.com/v2
kind: MySQLClusterSetFailover
metadata: {name: to-oc2}
spec: {clusterName: oc2, force: false}
Y
T0=$(date +%s); until [ "$(ro oc2-0)" = 0 ]; do sleep 2; [ $(( $(date +%s)-T0 )) -gt 600 ] && break; done; echo "SWITCHOVER oc2 writable after $(( $(date +%s)-T0 ))s; oc1 super_read_only=$(ro oc1-0)"; kubectl -n oracle get innodbcluster
sleep 30; echo "== isolate oc2 (NetworkPolicy deny all ingress/egress) $(date +%s%3N)"
cat <<Y | kubectl -n oracle apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: isolate-oc2}
spec:
  podSelector: {matchLabels: {mysql.oracle.com/cluster: oc2}}
  policyTypes: [Ingress, Egress]
Y
sleep 20
cat <<Y | kubectl -n oracle apply -f -
apiVersion: mysql.oracle.com/v2
kind: MySQLClusterSetFailover
metadata: {name: force-oc1}
spec: {clusterName: oc1, force: true}
Y
T1=$(date +%s); until [ "$(ro oc1-0)" = 0 ]; do sleep 3; [ $(( $(date +%s)-T1 )) -gt 900 ] && break; done; echo "FORCED_FAILOVER oc1 writable after $(( $(date +%s)-T1 ))s"
kubectl -n oracle get innodbcluster; kubectl -n oracle get mysqlclustersetfailover -o wide 2>/dev/null; kubectl -n oracle get events --sort-by=.lastTimestamp | grep -iE "fail|switch" | tail -5 | cut -c1-200

echo "OP_UPGRADE_START $(date +%s%3N)"
kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/crd.yaml 2>&1 | tail -1
kubectl -n pxc apply -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/rbac.yaml 2>&1 | tail -1
kubectl -n pxc patch deployment percona-xtradb-cluster-operator -p '{"spec":{"template":{"spec":{"containers":[{"name":"percona-xtradb-cluster-operator","image":"percona/percona-xtradb-cluster-operator:1.20.0"}]}}}}'
kubectl -n pxc rollout status deploy percona-xtradb-cluster-operator --timeout=300s; echo "OP_UPGRADED $(date +%s%3N)"; sleep 180
kubectl -n pxc get pxc; kubectl -n pxc get pods
echo "CR_UPDATE_START $(date +%s%3N)"
kubectl -n pxc patch pxc cluster1 --type=merge -p '{"spec":{"crVersion":"1.20.0","pxc":{"image":"percona/percona-xtradb-cluster:8.4.8-8.1"},"haproxy":{"image":"percona/haproxy:2.8.18-1"},"logcollector":{"image":"percona/fluentbit:5.0.6-1"},"backup":{"image":"percona/percona-xtrabackup:8.4.0-5.1"}}}'
T2=$(date +%s); sleep 60; until [ "$(kubectl -n pxc get pxc cluster1 -o jsonpath={.status.state})" = ready ] && [ "$(kubectl -n pxc get sts cluster1-pxc -o jsonpath={.status.updatedReplicas})" = 3 ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 1800 ] && break; done; echo "CR_UPDATED $(( $(date +%s)-T2 ))s"
for p in 0 1 2; do echo "pxc-$p $(sql cluster1-pxc-$p pxc 'select @@version')"; done; kubectl -n pxc get pods; kubectl -n pxc get pxc

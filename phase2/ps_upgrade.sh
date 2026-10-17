# PS operator 1.1.0 -> 1.2.0 per docs (update-crd-manual.md), then CR/db update
echo "OP_UPGRADE_START $(date +%s%3N)"
kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/crd.yaml 2>&1 | tail -1
kubectl -n ps apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/rbac.yaml 2>&1 | tail -1
kubectl -n ps apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/operator.yaml 2>&1 | tail -1
kubectl -n ps rollout status deploy percona-server-mysql-operator --timeout=300s; echo "OP_UPGRADED $(date +%s%3N)"; sleep 180
kubectl -n ps get ps; kubectl -n ps get pods
echo "CR_UPDATE_START $(date +%s%3N)"
kubectl -n ps patch ps ps-cluster1 --type=merge -p '{"spec":{"crVersion":"1.2.0","mysql":{"image":"percona/percona-server:8.4.10-10.1"},"backup":{"image":"percona/percona-xtrabackup:8.4.0-6.1"},"toolkit":{"image":"percona/percona-toolkit:3.7.1-4"}}}'
T2=$(date +%s); sleep 60; until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ] && [ "$(kubectl -n ps get sts ps-cluster1-mysql -o jsonpath={.status.updatedReplicas})" = 3 ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 1800 ] && break; done; echo "CR_UPDATED $(( $(date +%s)-T2 ))s"
for p in 0 1 2; do echo "mysql-$p $(sql ps-cluster1-mysql-$p mysql 'select @@version')"; done; kubectl -n ps get pods; kubectl -n ps get ps

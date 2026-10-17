kubectl create ns ps 2>/dev/null
kubectl -n ps apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.1.0/deploy/bundle.yaml 2>&1 | tail -1
kubectl -n ps rollout status deploy/percona-server-mysql-operator --timeout=300s
kubectl -n ps apply -f s3secret.yaml -f ps-cr-1.1.0.yaml
T1=$(date +%s); until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1500 ] && break; done; echo "READY $(( $(date +%s)-T1 ))s"
kubectl -n ps get ps; kubectl -n ps get pods

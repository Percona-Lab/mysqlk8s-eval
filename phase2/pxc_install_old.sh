kubectl create ns pxc 2>/dev/null
kubectl -n pxc apply --server-side -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.19.1/deploy/bundle.yaml 2>&1 | tail -1
kubectl -n pxc rollout status deploy/percona-xtradb-cluster-operator --timeout=300s
kubectl -n pxc apply -f s3secret.yaml -f pxc-cr-1.19.1.yaml
T1=$(date +%s); until [ "$(kubectl -n pxc get pxc cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1500 ] && break; done; echo "READY $(( $(date +%s)-T1 ))s"
kubectl -n pxc get pxc; kubectl -n pxc get pods

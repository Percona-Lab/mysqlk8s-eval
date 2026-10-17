kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.7.0-2.2.8/deploy/deploy-crds.yaml 2>&1 | tail -1
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/9.7.0-2.2.8/deploy/deploy-operator.yaml 2>&1 | tail -1
kubectl -n mysql-operator rollout status deploy/mysql-operator --timeout=300s
kubectl create ns oracle; kubectl -n oracle apply -f oracle-old.yaml
T1=$(date +%s); until [ "$(kubectl -n oracle get innodbcluster mycluster -o jsonpath={.status.cluster.status})" = ONLINE ] && [ "$(kubectl -n oracle get deploy mycluster-router -o jsonpath={.status.readyReplicas} 2>/dev/null)" = 3 ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1500 ] && break; done; echo "READY $(( $(date +%s)-T1 ))s"
kubectl -n oracle get innodbcluster; kubectl -n oracle get pods -o custom-columns=N:.metadata.name,IMG:.spec.containers[*].image | grep mycluster

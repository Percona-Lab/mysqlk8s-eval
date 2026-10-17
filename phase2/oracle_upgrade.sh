echo "OP_UPGRADE_START $(date +%s%3N)"
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/26.7.0-2.3.0/deploy/deploy-crds.yaml 2>&1 | tail -2
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/26.7.0-2.3.0/deploy/deploy-operator.yaml 2>&1 | tail -2
kubectl -n mysql-operator rollout status deploy/mysql-operator --timeout=300s; echo "OP_UPGRADED $(date +%s%3N)"; sleep 180
kubectl -n oracle get innodbcluster; kubectl -n oracle get pods -o custom-columns=N:.metadata.name,IMG:.spec.containers[*].image | grep mycluster
echo "DB_UPGRADE_START $(date +%s%3N)"
kubectl -n oracle patch innodbcluster mycluster --type=merge -p '{"spec":{"version":"26.7.0"}}'; T2=$(date +%s); sleep 60
until [ "$(kubectl -n oracle get sts mycluster -o jsonpath={.status.updatedReplicas})" = 3 ] && [ "$(kubectl -n oracle get innodbcluster mycluster -o jsonpath={.status.cluster.status})" = ONLINE ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 1800 ] && break; done; echo "DB_UPGRADED $(( $(date +%s)-T2 ))s"
for p in 0 1 2; do echo "mycluster-$p $(sql mycluster-$p mysql 'select @@version')"; done; kubectl -n oracle get pods -o custom-columns=N:.metadata.name,IMG:.spec.containers[*].image | grep mycluster; kubectl -n oracle get innodbcluster

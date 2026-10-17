RP=$(kubectl -n mdbmc get secret mariadb -o jsonpath={.data.password}|base64 -d)
ro(){ kubectl -n mdbmc exec $1 -c mariadb -- mariadb -uroot -p$RP -NBe "select @@read_only" 2>/dev/null; }
echo "== planned switchover (docs): maintenance on south $(date +%s%3N)"; T0=$(date +%s)
kubectl -n mdbmc patch mariadb mariadb-eu-south --type merge -p '{"spec":{"maintenance":{"enabled":true}}}'; sleep 20
kubectl -n mdbmc get mariadb mariadb-eu-central -o jsonpath='{.status.replication.replicas.mariadb-eu-central-0.secondsBehindMaster}'; echo
for m in mariadb-eu-south mariadb-eu-central; do kubectl -n mdbmc patch mariadb $m --type merge -p '{"spec":{"multiCluster":{"primary":"mariadb-eu-central"}}}'; done
until [ "$(ro mariadb-eu-central-0)" = 0 ]; do sleep 3; [ $(( $(date +%s)-T0 )) -gt 900 ] && break; done; echo "SWITCHOVER central-0 writable after $(( $(date +%s)-T0 ))s (from maintenance start); south-0 read_only=$(ro mariadb-eu-south-0)"
kubectl -n mdbmc patch mariadb mariadb-eu-south --type merge -p '{"spec":{"maintenance":{"enabled":false}}}'; sleep 60
kubectl -n mdbmc get mariadb -o custom-columns=N:.metadata.name,READY:.status.conditions[0].status,MSG:.status.conditions[0].message,MCP:.status.currentMultiClusterPrimary

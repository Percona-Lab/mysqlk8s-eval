R(){ kubectl -n mariadb exec mariadb-repl-0 -c mariadb -- mariadb -uroot -p"$(rp)" -NBe "$1" 2>&1 | grep -v "Using a pass"; }
R "create database if not exists pt; create table if not exists pt.t(id int auto_increment primary key, note varchar(40), ts datetime(6) default now(6)); insert into pt.t(note) values ('before-backup')"
for i in $(seq 1 30); do R "insert into pt.t(note) values ('pre-$i')" >/dev/null; sleep 2; done
T0=$(date +%s); until [ "$(kubectl -n mariadb get physicalbackup repl-base -o jsonpath="{.status.conditions[?(@.type==\"Complete\")].status}")" = True ]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 900 ] && break; done; echo "BASE_BACKUP_DONE +$(( $(date +%s)-T0 ))s"
R "insert into pt.t(note) values ('after-backup')"; sleep 5; TGT=$(date -u +%Y-%m-%dT%H:%M:%SZ); sleep 5
R "insert into pt.t(note) values ('after-target'); drop table pt.t"; echo "TARGET $TGT"; R "flush binary logs"
T1=$(date +%s); sleep 120; kubectl -n mariadb get pointintimerecovery pitr; kubectl -n mariadb logs mariadb-repl-0 -c agent --tail=3 2>&1 | cut -c1-200
cat <<Y | kubectl -n mariadb apply -f -
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata: {name: repl-pitr}
spec:
  rootPasswordSecretKeyRef: {name: mariadb-root, key: password}
  image: mariadb:12.3.3
  storage: {size: 5Gi}
  replicas: 1
  bootstrapFrom:
    pointInTimeRecoveryRef: {name: pitr}
    targetRecoveryTime: $TGT
  resources: {requests: {cpu: 200m, memory: 512Mi}}
Y
T2=$(date +%s); until [ "$(kubectl -n mariadb get mariadb repl-pitr -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}")" = True ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 1500 ] && break; done; echo "PITR_CLUSTER_READY $(( $(date +%s)-T2 ))s"
kubectl -n mariadb get mariadb repl-pitr; kubectl -n mariadb exec repl-pitr-0 -c mariadb -- mariadb -uroot -p"$(rp)" -NBe "select note from pt.t where note not like 'pre-%' order by id; select count(*) from pt.t" 2>&1 | grep -v "Using a pass"

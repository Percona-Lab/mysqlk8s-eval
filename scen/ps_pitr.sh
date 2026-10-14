B=$1; R=$2; PRI=$(sql $(dbpod) mysql "select member_host from performance_schema.replication_group_members where member_role='PRIMARY'" | cut -d. -f1); echo primary=$PRI
cat <<Y | kubectl -n ps apply -f -
apiVersion: ps.percona.com/v1
kind: PerconaServerMySQLBackup
metadata: {name: $B}
spec: {clusterName: ps-cluster1, storageName: s3}
Y
T0=$(date +%s); until [[ "$(kubectl -n ps get ps-backup $B -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 3; [ $(( $(date +%s)-T0 )) -gt 1200 ] && break; done; echo BACKUP $B $(kubectl -n ps get ps-backup $B -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s; kubectl -n ps get ps-backup
sql $PRI mysql "create table if not exists probe.marker(id int primary key, note varchar(40)); delete from probe.marker; insert into probe.marker values (1,'after-backup')"; sleep 3; TGT=$(date -u "+%Y-%m-%dT%H:%M:%SZ"); sleep 3
sql $PRI mysql "insert into probe.marker values (2,'after-target'); drop table sbtest.sbtest1"; echo TARGET $TGT; sleep 120
cat <<Y | kubectl -n ps apply -f -
apiVersion: ps.percona.com/v1
kind: PerconaServerMySQLRestore
metadata: {name: $R}
spec: {clusterName: ps-cluster1, backupName: $B, pitr: {type: date, date: "$TGT"}}
Y
T0=$(date +%s); until [[ "$(kubectl -n ps get ps-restore $R -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 1500 ] && break; done; echo RESTORE $(kubectl -n ps get ps-restore $R -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s; kubectl -n ps get ps-restore $R -o jsonpath='{.status}'; echo
T1=$(date +%s); until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 5; [ $(( $(date +%s)-T1 )) -gt 900 ] && break; done; echo CLUSTER_READY_AFTER $(( $(date +%s)-T1 ))s
sql $(dbpod) mysql "select * from probe.marker; select count(*) from sbtest.sbtest1; show tables from sbtest"; kubectl -n ps get pods | grep -E "mysql|haproxy"

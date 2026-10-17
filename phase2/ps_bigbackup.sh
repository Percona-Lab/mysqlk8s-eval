PRI=$(sql $(dbpod) mysql "select member_host from performance_schema.replication_group_members where member_role='PRIMARY'" | cut -d. -f1)
cat <<Y | kubectl -n ps apply -f -
apiVersion: ps.percona.com/v1
kind: PerconaServerMySQLBackup
metadata: {name: bigbk2}
spec: {clusterName: ps-cluster1, storageName: s3}
Y
T0=$(date +%s); echo "BACKUP_START $(date +%s%3N)"; until [[ "$(kubectl -n ps get ps-backup bigbk2 -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 7200 ] && break; done; echo "BACKUP $(kubectl -n ps get ps-backup bigbk2 -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s $(date +%s%3N)"
sql $PRI mysql "create table if not exists probe.marker(id int primary key, note varchar(40)); delete from probe.marker; insert into probe.marker values (1,'after-backup')"; sleep 3; TGT=$(date -u "+%Y-%m-%d %H:%M:%S"); sleep 3
sql $PRI mysql "insert into probe.marker values (2,'after-target'); drop table sbbig.sbtest7"; echo "TARGET $TGT"; sleep 180
cat <<Y | kubectl -n ps apply -f -
apiVersion: ps.percona.com/v1
kind: PerconaServerMySQLRestore
metadata: {name: bigpitr2}
spec: {clusterName: ps-cluster1, backupName: bigbk2, pitr: {type: date, date: "$TGT"}}
Y
T1=$(date +%s); echo "RESTORE_START $(date +%s%3N)"; until [[ "$(kubectl -n ps get ps-restore bigpitr2 -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 7200 ] && break; done; echo "RESTORE $(kubectl -n ps get ps-restore bigpitr2 -o jsonpath={.status}) $(( $(date +%s)-T1 ))s"
T2=$(date +%s); until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 3600 ] && break; done; echo "CLUSTER_READY_AFTER_RESTORE $(( $(date +%s)-T2 ))s $(date +%s%3N)"
sql $(dbpod) mysql "select * from probe.marker; select count(*) from sbbig.sbtest7"

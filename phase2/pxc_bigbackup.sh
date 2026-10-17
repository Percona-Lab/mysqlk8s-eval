PRI=cluster1-pxc-0
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata: {name: bigbk3}
spec: {pxcCluster: cluster1, storageName: s3}
Y
T0=$(date +%s); echo "BACKUP_START $(date +%s%3N)"; until [[ "$(kubectl -n pxc get pxc-backup bigbk3 -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 7200 ] && break; done; echo "BACKUP $(kubectl -n pxc get pxc-backup bigbk3 -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s $(date +%s%3N)"
sql $PRI pxc "create table if not exists probe.marker(id int primary key, note varchar(40)); delete from probe.marker; insert into probe.marker values (1,'after-backup')"; sleep 3; TGT=$(date -u "+%Y-%m-%d %H:%M:%S"); sleep 3
sql $PRI pxc "insert into probe.marker values (2,'after-target'); drop table sbbig.sbtest6"; echo "TARGET $TGT"; sleep 180
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata: {name: bigpitr3}
spec: {pxcCluster: cluster1, backupName: bigbk3, pitr: {type: date, date: "$TGT", backupSource: {storageName: s3}}}
Y
T1=$(date +%s); echo "RESTORE_START $(date +%s%3N)"; until [[ "$(kubectl -n pxc get pxc-restore bigpitr3 -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 7200 ] && break; done; echo "RESTORE $(kubectl -n pxc get pxc-restore bigpitr3 -o jsonpath={.status}) $(( $(date +%s)-T1 ))s"
T2=$(date +%s); until [ "$(kubectl -n pxc get pxc cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 3600 ] && break; done; echo "CLUSTER_READY_AFTER_RESTORE $(( $(date +%s)-T2 ))s $(date +%s%3N)"
sql cluster1-pxc-0 pxc "select * from probe.marker; select count(*) from sbbig.sbtest6"
RS=$(date -u -d @$T1 "+%Y-%m-%d %H:%M:%S"); echo "probe rows between target and restore start (expect 0): $(sql cluster1-pxc-0 pxc "select count(*) from probe.t where ts > '$TGT' and ts < '$RS'")"

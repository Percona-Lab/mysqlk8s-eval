B=$1; R=$2
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata: {name: $B}
spec: {pxcCluster: cluster1, storageName: s3}
Y
T0=$(date +%s); until [[ "$(kubectl -n pxc get pxc-backup $B -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 3; done; echo BACKUP $B $(kubectl -n pxc get pxc-backup $B -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s
sql cluster1-pxc-0 pxc "create table if not exists probe.marker(id int primary key, note varchar(40)); create table if not exists sbtest.sbtest1 like sbtest.sbtest2; delete from probe.marker; insert into probe.marker values (1,'after-backup')"; sleep 3; TGT=$(date -u "+%Y-%m-%d %H:%M:%S"); sleep 3
sql cluster1-pxc-0 pxc "insert into probe.marker values (2,'after-target'); drop table sbtest.sbtest1"; echo TARGET $TGT; sleep 150
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata: {name: $R}
spec: {pxcCluster: cluster1, backupName: $B, pitr: {type: date, date: "$TGT", backupSource: {storageName: s3}}}
Y
T0=$(date +%s); until [[ "$(kubectl -n pxc get pxc-restore $R -o jsonpath={.status.state})" =~ Succeeded|Failed|Error ]]; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 1200 ] && break; done; echo RESTORE $(kubectl -n pxc get pxc-restore $R -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s
kubectl -n pxc logs job/pitr-job-$R-cluster1 --tail=3 2>&1 | cut -c1-200
T1=$(date +%s); until [ "$(kubectl -n pxc get pxc cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 5; [ $(( $(date +%s)-T1 )) -gt 900 ] && break; done; echo CLUSTER_READY_AFTER $(( $(date +%s)-T1 ))s
sql cluster1-pxc-0 pxc "select * from probe.marker; select count(*) from sbtest.sbtest1; show tables from sbtest"; kubectl -n pxc get pods | grep -E "pxc-|haproxy"

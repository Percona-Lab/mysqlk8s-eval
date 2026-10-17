cat <<Y | kubectl -n oracle apply -f -
apiVersion: mysql.oracle.com/v2
kind: MySQLBackup
metadata: {name: bigdump}
spec: {clusterName: mycluster, backupProfileName: s3dump}
Y
T0=$(date +%s); echo "BACKUP_START $(date +%s%3N)"; until [[ "$(kubectl -n oracle get mysqlbackup bigdump -o jsonpath={.status.status})" =~ Completed|Failed|Error ]]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 7200 ] && break; done
echo "BACKUP $(kubectl -n oracle get mysqlbackup bigdump -o jsonpath={.status.status}) $(( $(date +%s)-T0 ))s $(date +%s%3N)"; OUT=$(kubectl -n oracle get mysqlbackup bigdump -o jsonpath={.status.output}); echo "output=$OUT elapsed=$(kubectl -n oracle get mysqlbackup bigdump -o jsonpath={.status.elapsedTime})"
cat <<Y | kubectl -n oracle apply -f -
apiVersion: mysql.oracle.com/v2
kind: InnoDBCluster
metadata: {name: bigrestored}
spec:
  secretName: mypwds
  tlsUseSelfSigned: true
  instances: 1
  router: {instances: 1}
  datadirVolumeClaimTemplate: {accessModes: [ReadWriteOnce], resources: {requests: {storage: 20Gi}}}
  initDB:
    dump:
      name: bigdump
      storage:
        s3: {bucketName: oracle, prefix: "dumps/$OUT", config: s3-config, profile: default, endpoint: "http://s3.s3.svc:9000"}
Y
T1=$(date +%s); until [ "$(kubectl -n oracle get innodbcluster bigrestored -o jsonpath={.status.cluster.status})" = ONLINE ]; do sleep 15; [ $(( $(date +%s)-T1 )) -gt 7200 ] && break; done; echo "RESTORE_NEW_CLUSTER_ONLINE $(( $(date +%s)-T1 ))s"
kubectl -n oracle logs bigrestored-0 -c sidecar 2>/dev/null | grep -E "loaded in|Data load duration" | tail -2 | cut -c1-200
sql bigrestored-0 mysql "select count(*) from sbbig.sbtest8"
kubectl -n oracle delete innodbcluster bigrestored --wait=false; sleep 20; kubectl -n oracle delete pvc datadir-bigrestored-0 --wait=false

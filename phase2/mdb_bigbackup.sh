# physical backup of ~10GB under load, then bootstrap new 1-node cluster from it
cat <<Y | kubectl -n mariadb apply -f -
apiVersion: k8s.mariadb.com/v1alpha1
kind: PhysicalBackup
metadata: {name: bigphys}
spec:
  mariaDbRef: {name: mariadb-galera}
  target: Replica
  compression: bzip2
  storage:
    s3: {bucket: mariadb, prefix: bigphys, endpoint: "s3.s3.svc:9000", region: us-east-1, accessKeyIdSecretKeyRef: {name: s3-creds, key: access-key-id}, secretAccessKeySecretKeyRef: {name: s3-creds, key: secret-access-key}}
  stagingStorage: {persistentVolumeClaim: {resources: {requests: {storage: 20Gi}}, accessModes: [ReadWriteOnce]}}
  timeout: 3h
Y
T0=$(date +%s); echo "BACKUP_START $(date +%s%3N)"; until [ "$(kubectl -n mariadb get physicalbackup bigphys -o jsonpath="{.status.conditions[?(@.type==\"Complete\")].status}")" = True ]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 10800 ] && break; done; echo "BACKUP_DONE $(( $(date +%s)-T0 ))s $(date +%s%3N)"; kubectl -n mariadb get physicalbackup bigphys
echo "s3.bucket.list" | kubectl -n s3 exec -i deploy/s3 -- weed shell 2>/dev/null | grep mariadb
cat <<Y | kubectl -n mariadb apply -f -
apiVersion: k8s.mariadb.com/v1alpha1
kind: MariaDB
metadata: {name: bigrestored}
spec:
  rootPasswordSecretKeyRef: {name: mariadb-root, key: password}
  image: mariadb:12.3.3
  storage: {size: 20Gi}
  replicas: 1
  bootstrapFrom:
    backupRef: {name: bigphys, kind: PhysicalBackup}
    stagingStorage: {persistentVolumeClaim: {resources: {requests: {storage: 20Gi}}, accessModes: [ReadWriteOnce]}}
Y
T1=$(date +%s); until [ "$(kubectl -n mariadb get mariadb bigrestored -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}")" = True ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 10800 ] && break; done; echo "RESTORE_NEW_CLUSTER_READY $(( $(date +%s)-T1 ))s"
sql bigrestored-0 mariadb "select count(*) from sbbig.sbtest8"
kubectl -n mariadb delete mariadb bigrestored --wait=false; sleep 10; kubectl -n mariadb delete pvc -l app.kubernetes.io/instance=bigrestored --wait=false

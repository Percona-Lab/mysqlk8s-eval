# run on mb-cp: args NAME TYPE GTID ; fresh cluster2 from xdrbk + PITR, then check markers
NAME=$1; TYPE=$2; G=$3; A=<MK_CP_PUBIP>; DEST=s3://pxc/p3/cluster1-2026-10-17-06:57:10-full
kubectl -n pxc delete pxc cluster2 --wait=true --timeout=300s >/dev/null 2>&1; kubectl -n pxc delete pxc-restore --all >/dev/null 2>&1; kubectl -n pxc delete pvc --all --wait=true --timeout=300s >/dev/null 2>&1
kubectl -n pxc apply -f /root/pxc-b.yaml >/dev/null; T1=$(date +%s); until [ "$(kubectl -n pxc get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1500 ] && break; done; echo "B_CLUSTER_READY $(( $(date +%s)-T1 ))s"
S3="{bucket: pxc, credentialsSecret: s3-creds, endpointUrl: \"http://$A:30900\", region: us-east-1, forcePathStyle: true}"
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata: {name: $NAME}
spec:
  pxcCluster: cluster2
  backupSource: {destination: $DEST, s3: $S3}
  pitr:
    type: $TYPE
    gtid: "$G"
    backupSource: {s3: $S3}
Y
T2=$(date +%s); until [[ "$(kubectl -n pxc get pxc-restore $NAME -o jsonpath={.status.state})" =~ Succeeded|Failed ]]; do sleep 15; [ $(( $(date +%s)-T2 )) -gt 7200 ] && break; done
echo "RESTORE $NAME $(kubectl -n pxc get pxc-restore $NAME -o jsonpath='{.status.state} {.status.comments}') $(( $(date +%s)-T2 ))s"
until [ "$(kubectl -n pxc get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; done
RP=$(kubectl -n pxc get secret cluster2-secrets -o jsonpath={.data.root}|base64 -d)
kubectl -n pxc exec cluster2-pxc-0 -c pxc -- env MYSQL_PWD="$RP" mysql -uroot -NBe "select 'MARKERS', group_concat(v order by id) from pitrt.m; select 'PROBE_LT_50000', count(*) from probe.t where id<50000; select 'GTID', @@gtid_executed" 2>&1

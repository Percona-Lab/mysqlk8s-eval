# site B part (run on mb-cp): args DEST NP0 NP1 NP2 ; uses /root/xdr-secrets.json /root/s3secret.yaml /root/pxc-b.yaml
DEST=$1; A=<MK_CP_PUBIP>
kubectl create ns pxc; kubectl -n pxc apply -f /root/xdr-secrets.json -f /root/s3secret.yaml
kubectl -n pxc apply --server-side -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/bundle.yaml >/dev/null; kubectl -n pxc rollout status deploy/percona-xtradb-cluster-operator --timeout=300s >/dev/null
kubectl -n pxc apply -f /root/pxc-b.yaml; T1=$(date +%s); until [ "$(kubectl -n pxc get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1500 ] && break; done; echo "B_CLUSTER_READY $(( $(date +%s)-T1 ))s"
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata: {name: xdrrestore}
spec:
  pxcCluster: cluster2
  backupSource:
    destination: $DEST
    s3: {bucket: pxc, credentialsSecret: s3-creds, endpointUrl: "http://$A:30900", region: us-east-1, forcePathStyle: true}
Y
T2=$(date +%s); until [[ "$(kubectl -n pxc get pxc-restore xdrrestore -o jsonpath={.status.state})" =~ Succeeded|Failed ]]; do sleep 15; [ $(( $(date +%s)-T2 )) -gt 5400 ] && break; done; echo "B_RESTORE $(kubectl -n pxc get pxc-restore xdrrestore -o jsonpath={.status.state}) $(( $(date +%s)-T2 ))s"
until [ "$(kubectl -n pxc get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; done
kubectl -n pxc patch pxc cluster2 --type=merge -p "{\"spec\":{\"pxc\":{\"replicationChannels\":[{\"name\":\"a_to_b\",\"isSource\":false,\"sourcesList\":[{\"host\":\"$A\",\"port\":$2,\"weight\":100},{\"host\":\"$A\",\"port\":$3,\"weight\":90},{\"host\":\"$A\",\"port\":$4,\"weight\":80}]}]}}}"
RP=$(kubectl -n pxc get secret cluster2-secrets -o jsonpath={.data.root}|base64 -d); T3=$(date +%s)
for i in $(seq 1 60); do s=$(kubectl -n pxc exec cluster2-pxc-0 -c pxc -- mysql -uroot -p"$RP" -e "show replica status\G" 2>/dev/null | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_IO_Error:" | tr -s " " | tr "\n" " "); echo "+$(( $(date +%s)-T3 ))s $s"; sleep 20; done

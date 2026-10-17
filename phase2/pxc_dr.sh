set -x
# 1) source side: expose pods + replication channel (isSource)
kubectl -n pxc patch pxc cluster1 --type=merge -p '{"spec":{"pxc":{"expose":{"enabled":true,"type":"ClusterIP"},"replicationChannels":[{"name":"pxc1_to_pxc2","isSource":true}]}}}'
sleep 120; kubectl -n pxc get svc | grep -E "cluster1-pxc-[0-9]"
# 2) backup on source
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata: {name: drbk}
spec: {pxcCluster: cluster1, storageName: s3}
Y
T0=$(date +%s); until [[ "$(kubectl -n pxc get pxc-backup drbk -o jsonpath={.status.state})" =~ Succeeded|Failed ]]; do sleep 10; done; echo "DR_BACKUP $(kubectl -n pxc get pxc-backup drbk -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s"; DEST=$(kubectl -n pxc get pxc-backup drbk -o jsonpath={.status.destination}); echo DEST=$DEST
# 3) replica site cluster2 (size 1) in ns pxc2 with same secrets
kubectl create ns pxc2; kubectl -n pxc get secret cluster1-secrets -o json | python3 -c "import json,sys; d=json.load(sys.stdin); d['metadata']={'name':'cluster2-secrets'}; print(json.dumps(d))" | kubectl -n pxc2 apply -f -
kubectl -n pxc get secret s3-creds -o json | python3 -c "import json,sys; d=json.load(sys.stdin); d['metadata']={'name':'s3-creds'}; print(json.dumps(d))" | kubectl -n pxc2 apply -f -
kubectl -n pxc2 apply --server-side -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/bundle.yaml >/dev/null; kubectl -n pxc2 rollout status deploy/percona-xtradb-cluster-operator --timeout=300s
python3 - <<P
import yaml
d=yaml.safe_load(open('/root/pxc-cr.yaml')); d['metadata']['name']='cluster2'; s=d['spec']
s['unsafeFlags']={'pxcSize':True,'proxySize':True}; s['pxc']['size']=1; s['haproxy']['size']=1
s['pxc']['resources']={'requests':{'memory':'512M','cpu':'200m'}}; s['haproxy']['resources']={'requests':{'memory':'128M','cpu':'100m'}}
s['pxc']['volumeSpec']['persistentVolumeClaim']['resources']['requests']['storage']='10G'
s['backup']['pitr']['enabled']=False; s.pop('pmm',None)
yaml.safe_dump(d,open('/root/pxc-cr2.yaml','w'),sort_keys=False)
P
kubectl -n pxc2 apply -f /root/pxc-cr2.yaml; T1=$(date +%s); until [ "$(kubectl -n pxc2 get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 1200 ] && break; done; echo "CLUSTER2_READY $(( $(date +%s)-T1 ))s"
# 4) restore source backup into cluster2
cat <<Y | kubectl -n pxc2 apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterRestore
metadata: {name: drrestore}
spec:
  pxcCluster: cluster2
  backupSource:
    destination: $DEST
    s3: {bucket: pxc/p2, credentialsSecret: s3-creds, endpointUrl: "http://s3.s3.svc:9000", region: us-east-1}
Y
T2=$(date +%s); until [[ "$(kubectl -n pxc2 get pxc-restore drrestore -o jsonpath={.status.state})" =~ Succeeded|Failed ]]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 3600 ] && break; done; echo "DR_RESTORE $(kubectl -n pxc2 get pxc-restore drrestore -o jsonpath={.status.state}) $(( $(date +%s)-T2 ))s"
until [ "$(kubectl -n pxc2 get pxc cluster2 -o jsonpath={.status.state})" = ready ]; do sleep 10; done
# 5) replication channel on cluster2
kubectl -n pxc2 patch pxc cluster2 --type=merge -p '{"spec":{"pxc":{"replicationChannels":[{"name":"pxc1_to_pxc2","isSource":false,"sourcesList":[{"host":"cluster1-pxc-0.pxc.svc.cluster.local","weight":100},{"host":"cluster1-pxc-1.pxc.svc.cluster.local","weight":100},{"host":"cluster1-pxc-2.pxc.svc.cluster.local","weight":100}]}]}}}'
T3=$(date +%s); sleep 60; RP=$(kubectl -n pxc get secret cluster1-secrets -o jsonpath={.data.root}|base64 -d)
for i in $(seq 1 30); do s=$(kubectl -n pxc2 exec cluster2-pxc-0 -c pxc -- mysql -uroot -p"$RP" -e "show replica status\G" 2>/dev/null | grep -E "Replica_IO_Running:|Replica_SQL_Running:|Seconds_Behind_Source:|Last_IO_Error:|Last_SQL_Error:" | tr -s " " | tr "\n" " "); echo "+$(( $(date +%s)-T3 ))s $s"; echo "$s" | grep -q "Seconds_Behind_Source: 0" && break; sleep 20; done
echo "rows src=$(kubectl -n pxc exec cluster1-pxc-0 -c pxc -- mysql -uroot -p"$RP" -NBe 'select count(*) from probe.t' 2>/dev/null) dst=$(kubectl -n pxc2 exec cluster2-pxc-0 -c pxc -- mysql -uroot -p"$RP" -NBe 'select count(*) from probe.t' 2>/dev/null)"

# run on mk-cp: Oracle MySQL Operator 26.7.0-2.3.0 + InnoDBCluster on CSI, 16 GB data, probe + load
cd /root; source h.sh; OP=oracle; NS=oracle
kubectl -n s3 exec deploy/s3 -- sh -c 'echo "s3.bucket.create -name oracle" | weed shell' >/dev/null 2>&1
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/26.7.0-2.3.0/deploy/deploy-crds.yaml >/dev/null
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/26.7.0-2.3.0/deploy/deploy-operator.yaml >/dev/null; kubectl -n mysql-operator rollout status deploy/mysql-operator --timeout=300s >/dev/null; echo OPERATOR_OK
kubectl create ns oracle >/dev/null; T=$(date +%s); kubectl -n oracle apply -f oracle-p3.yaml >/dev/null
until [ "$(kubectl -n oracle get innodbcluster mycluster -o jsonpath={.status.cluster.status})" = ONLINE ] && [ "$(kubectl -n oracle get deploy mycluster-router -o jsonpath={.status.readyReplicas} 2>/dev/null)" = 3 ]; do sleep 10; [ $(( $(date +%s)-T )) -gt 1500 ] && break; done; echo "READY on CSI $(( $(date +%s)-T ))s"
kubectl -n oracle get pvc; kubectl -n oracle get pods -o wide
PRI=$(kubectl -n oracle get pods -l mysql.oracle.com/cluster-role=PRIMARY -o name | cut -d/ -f2); echo primary=$PRI
sql $PRI mysql "create database probe; create table probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16)); create user probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'; create database sbtest; create database sbbig; create user sb@'%' identified by 'SbPass123'; grant all on sbtest.* to sb@'%'; grant all on sbbig.* to sb@'%'"
bash mkprobe.sh oracle oracle mycluster.oracle probe ProbePass123 percona/percona-server:8.4 >/dev/null
ROWS=1000000 bash sysb.sh oracle mycluster.oracle sb SbPass123 prepare --mysql-ssl=REQUIRED | tail -1
T=$(date +%s); BIGDB=sbbig bash bigload.sh oracle mycluster.oracle sb SbPass123 --mysql-ssl=REQUIRED >/dev/null 2>&1; until [[ "$(kubectl -n oracle get pod bigprep -o jsonpath={.status.phase})" =~ Succeeded|Failed ]]; do sleep 30; done; echo "BIGPREP $(kubectl -n oracle get pod bigprep -o jsonpath={.status.phase}) $(( $(date +%s)-T ))s"
sleep 300; kubectl -n oracle get pods; kubectl -n oracle get innodbcluster
bash load.sh start oracle mycluster.oracle sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n oracle logs load | tail -1; kubectl -n oracle logs probe-oracle | tail -1; echo ORACLE_SETUP_DONE

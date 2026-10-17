# run on mb-cp: S3 + PS operator 1.2.0 + PS cluster on CSI, 16 GB data, probe + load
cd /root; source h.sh; OP=ps; NS=ps
kubectl apply -f s3.yaml >/dev/null; kubectl -n s3 rollout status deploy/s3 --timeout=300s >/dev/null; sleep 20
kubectl -n s3 exec deploy/s3 -- sh -c 'echo "s3.bucket.create -name psbk3" | weed shell' >/dev/null 2>&1; echo S3_OK
kubectl create ns ps >/dev/null; kubectl -n ps apply -f s3secret-ps.yaml >/dev/null
kubectl -n ps apply --server-side -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/bundle.yaml >/dev/null; kubectl -n ps rollout status deploy/percona-server-mysql-operator --timeout=300s >/dev/null
T=$(date +%s); kubectl -n ps apply -f ps-p3.yaml >/dev/null; until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T )) -gt 1500 ] && break; done; echo "READY on CSI $(( $(date +%s)-T ))s"
kubectl -n ps get pvc; kubectl -n ps get pods -o wide | grep -v Completed
PRI=$(kubectl -n ps get pods -l app.kubernetes.io/component=database -o name | head -1 | cut -d/ -f2); PRI=$(sql $PRI mysql "select member_host from performance_schema.replication_group_members where member_role='PRIMARY'" | cut -d. -f1); echo primary=$PRI
sql $PRI mysql "create database probe; create table probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16)); create user probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'; create database sbtest; create database sbbig; create user sb@'%' identified by 'SbPass123'; grant all on sbtest.* to sb@'%'; grant all on sbbig.* to sb@'%'"
bash mkprobe.sh ps ps ps-cluster1-haproxy.ps probe ProbePass123 percona/percona-server:8.4 >/dev/null
ROWS=1000000 bash sysb.sh ps ps-cluster1-haproxy.ps sb SbPass123 prepare --mysql-ssl=REQUIRED | tail -1
T=$(date +%s); BIGDB=sbbig bash bigload.sh ps ps-cluster1-haproxy.ps sb SbPass123 --mysql-ssl=REQUIRED >/dev/null 2>&1; until [[ "$(kubectl -n ps get pod bigprep -o jsonpath={.status.phase})" =~ Succeeded|Failed ]]; do sleep 30; done; echo "BIGPREP $(kubectl -n ps get pod bigprep -o jsonpath={.status.phase}) $(( $(date +%s)-T ))s"
kubectl -n ps get pods | grep mysql-
bash load.sh start ps ps-cluster1-haproxy.ps sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n ps logs load | tail -1; kubectl -n ps logs probe-ps | tail -1; echo PS_SETUP_DONE

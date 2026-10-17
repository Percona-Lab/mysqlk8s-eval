PRI=$(kubectl -n ps get pods -l app.kubernetes.io/component=database -o name | head -1 | cut -d/ -f2); PRI=$(sql $PRI mysql "select member_host from performance_schema.replication_group_members where member_role='PRIMARY'" | cut -d. -f1); echo primary=$PRI
sql $PRI mysql "create database probe; create table probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16)); create user probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'; create database sbtest; create database sbbig; create user sb@'%' identified by 'SbPass123'; grant all on sbtest.* to sb@'%'; grant all on sbbig.* to sb@'%'"
bash mkprobe.sh ps ps ps-cluster1-haproxy.ps probe ProbePass123 percona/percona-server:8.4 >/dev/null
bash sysb.sh ps ps-cluster1-haproxy.ps sb SbPass123 prepare --mysql-ssl=REQUIRED | tail -1
bash load.sh start ps ps-cluster1-haproxy.ps sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n ps logs load | tail -1; kubectl -n ps logs probe-ps | tail -1

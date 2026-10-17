PRI=$(kubectl -n oracle get pods -l mysql.oracle.com/cluster-role=PRIMARY -o name | cut -d/ -f2); echo primary=$PRI
sql $PRI mysql "create database probe; create table probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16)); create user probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'; create database sbtest; create database sbbig; create user sb@'%' identified by 'SbPass123'; grant all on sbtest.* to sb@'%'; grant all on sbbig.* to sb@'%'"
bash mkprobe.sh oracle oracle mycluster.oracle probe ProbePass123 percona/percona-server:8.4 >/dev/null
bash sysb.sh oracle mycluster.oracle sb SbPass123 prepare --mysql-ssl=REQUIRED | tail -1
bash load.sh start oracle mycluster.oracle sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n oracle logs load | tail -1; kubectl -n oracle logs probe-oracle | tail -1

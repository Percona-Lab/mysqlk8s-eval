sql cluster1-pxc-0 pxc "create database probe; create table probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16)); create user probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'; create database sbtest; create database sbbig; create user sb@'%' identified by 'SbPass123'; grant all on sbtest.* to sb@'%'; grant all on sbbig.* to sb@'%'"
bash mkprobe.sh pxc pxc cluster1-haproxy.pxc probe ProbePass123 percona/percona-server:8.4 >/dev/null
bash sysb.sh pxc cluster1-haproxy.pxc sb SbPass123 prepare --mysql-ssl=REQUIRED | tail -1
bash load.sh start pxc cluster1-haproxy.pxc sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n pxc logs load | tail -1; kubectl -n pxc logs probe-pxc | tail -1

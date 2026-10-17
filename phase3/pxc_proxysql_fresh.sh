# run on mb-cp: fresh PXC + ProxySQL; track runtime_mysql_users per ProxySQL pod
kubectl -n pxc delete pxc cluster2 --wait=true --timeout=300s >/dev/null 2>&1; kubectl -n pxc delete pxc-restore --all >/dev/null 2>&1; kubectl -n pxc delete pvc --all --wait=true --timeout=300s >/dev/null 2>&1
T0=$(date +%s); kubectl -n pxc apply -f /root/pxc-b-proxysql.yaml
until [ "$(kubectl -n pxc get pxc cluster3 -o jsonpath={.status.state})" = ready ]; do sleep 10; [ $(( $(date +%s)-T0 )) -gt 1500 ] && break; done; echo "READY $(( $(date +%s)-T0 ))s"
AP=$(kubectl -n pxc get secret cluster3-secrets -o jsonpath={.data.proxyadmin}|base64 -d); RP=$(kubectl -n pxc get secret cluster3-secrets -o jsonpath={.data.root}|base64 -d)
kubectl -n pxc exec cluster3-pxc-0 -c pxc -- env MYSQL_PWD="$RP" mysql -uroot -e "create database if not exists probe; create table if not exists probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(8)); create user if not exists probe@'%' identified by 'ProbePass123'; grant all on probe.* to probe@'%'"; echo "APP_USER_CREATED +$(( $(date +%s)-T0 ))s"
for i in $(seq 1 40); do
  l="+$(( $(date +%s)-T0 ))s"
  for p in 0 1 2; do c=$(kubectl -n pxc exec cluster3-proxysql-$p -c proxysql -- env MYSQL_PWD="$AP" mysql -h127.0.0.1 -P6032 -uproxyadmin -NBe "select count(*), sum(username='probe') from runtime_mysql_users" 2>/dev/null | tr '\t' '/'); l="$l p$p=$c"; done
  ok=0; for k in $(seq 1 6); do kubectl -n pxc exec cluster3-pxc-0 -c pxc -- mysql -hcluster3-proxysql -uprobe -pProbePass123 -NBe "select 1" >/dev/null 2>&1 && ok=$((ok+1)); done
  echo "$l probe_logins_ok=$ok/6"; sleep 30
done
kubectl -n pxc logs deploy/percona-xtradb-cluster-operator --since=30m | grep -iE "sync users|UNIQUE" | cut -c1-250 | tail -5

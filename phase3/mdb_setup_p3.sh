# run on mk-cp: MariaDB operator 26.10.1 + Galera(3) + MaxScale(3) on CSI, 16 GB data, probe + load
cd /root; source h.sh; OP=mariadb; NS=mariadb; export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl -n s3 exec deploy/s3 -- sh -c 'echo "s3.bucket.create -name mdbp3" | weed shell' >/dev/null 2>&1
helm upgrade --install mariadb-operator-crds oci://ghcr.io/mariadb-operator/charts/mariadb-operator-crds --version 26.10.1 >/dev/null 2>&1
helm upgrade --install mariadb-operator oci://ghcr.io/mariadb-operator/charts/mariadb-operator --version 26.10.1 -n mariadb-system --create-namespace >/dev/null 2>&1
kubectl -n mariadb-system rollout status deploy/mariadb-operator --timeout=300s >/dev/null; echo OPERATOR_OK
kubectl create ns mariadb >/dev/null; T=$(date +%s); kubectl -n mariadb apply -f mariadb-p3.yaml >/dev/null
until [ "$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] && [ "$(kubectl -n mariadb get maxscale maxscale-galera -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ]; do sleep 10; [ $(( $(date +%s)-T )) -gt 1800 ] && break; done; echo "READY on CSI $(( $(date +%s)-T ))s"
kubectl -n mariadb apply -f mariadb-users.yaml -f mdb_extra.yaml >/dev/null; sleep 20
kubectl -n mariadb patch user sb --type=merge -p '{"spec":{"maxUserConnections":200}}'; kubectl -n mariadb patch user probe --type=merge -p '{"spec":{"maxUserConnections":200}}'; sleep 30
kubectl -n mariadb get pvc; kubectl -n mariadb get pods -o wide
sql mariadb-galera-0 mariadb "create table if not exists probe.t(id bigint auto_increment primary key, ts datetime(6), src varchar(16))"
bash mkprobe.sh mariadb mariadb maxscale-galera.mariadb probe ProbePass123 mariadb:11.8 mariadb >/dev/null
ROWS=1000000 bash sysb.sh mariadb maxscale-galera.mariadb sb SbPass123 prepare | tail -1
T=$(date +%s); BIGDB=sbbig bash bigload.sh mariadb maxscale-galera.mariadb sb SbPass123 >/dev/null 2>&1; until [[ "$(kubectl -n mariadb get pod bigprep -o jsonpath={.status.phase})" =~ Succeeded|Failed ]]; do sleep 30; done; echo "BIGPREP $(kubectl -n mariadb get pod bigprep -o jsonpath={.status.phase}) $(( $(date +%s)-T ))s"; kubectl -n mariadb logs bigprep | tail -1 | cut -c1-150
kubectl -n mariadb get pods | grep galera; kubectl -n mariadb exec mariadb-galera-0 -c mariadb -- df -h /var/lib/mysql | tail -1
bash load.sh start mariadb maxscale-galera.mariadb sb SbPass123 50; sleep 40; kubectl -n mariadb logs load | tail -1; kubectl -n mariadb logs probe-mariadb | tail -1; echo MDB_SETUP_DONE

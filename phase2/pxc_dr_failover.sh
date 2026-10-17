RP=$(kubectl -n pxc get secret cluster1-secrets -o jsonpath={.data.root}|base64 -d)
echo "SITE1_DOWN $(date +%s%3N)"; kubectl -n pxc patch pxc cluster1 --type=merge -p '{"spec":{"pause":true}}'
until [ -z "$(kubectl -n pxc get pods -l app.kubernetes.io/component=pxc -o name)" ]; do sleep 5; done; echo "SITE1_STOPPED $(date +%s%3N)"
kubectl -n pxc2 exec cluster2-pxc-0 -c pxc -- mysql -uroot -p"$RP" -e "show replica status\G" 2>/dev/null | grep -E "Retrieved_Gtid_Set|Executed_Gtid_Set" -A1 | head -6
kubectl -n pxc2 patch pxc cluster2 --type=merge -p '{"spec":{"pxc":{"replicationChannels":[{"name":"pxc1_to_pxc2","isSource":true}]}}}'; T0=$(date +%s)
until [ "$(kubectl -n pxc2 exec cluster2-pxc-0 -c pxc -- mysql -uroot -p"$RP" -NBe 'select @@read_only' 2>/dev/null)" = 0 ]; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 900 ] && break; done; echo "CLUSTER2_WRITABLE after promote $(( $(date +%s)-T0 ))s $(date +%s%3N)"
bash mkprobe.sh pxc2 pxc2 cluster2-haproxy.pxc2 probe ProbePass123 percona/percona-server:8.4 >/dev/null; sleep 30; kubectl -n pxc2 logs probe-pxc2 | tail -2

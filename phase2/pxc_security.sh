echo "== root password rotation via cluster1-secrets"
OLD=$(kubectl -n pxc get secret cluster1-secrets -o jsonpath={.data.root}|base64 -d)
kubectl -n pxc patch secret cluster1-secrets --type=merge -p '{"stringData":{"root":"CHANGE_ME_ROTATED"}}' >/dev/null; T0=$(date +%s)
until kubectl -n pxc exec cluster1-pxc-0 -c pxc -- mysql -uroot -p'CHANGE_ME_ROTATED' -NBe "select 1" >/dev/null 2>&1; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 600 ] && break; done; echo "NEW_ROOT_WORKS_AFTER $(( $(date +%s)-T0 ))s"
kubectl -n pxc exec cluster1-pxc-0 -c pxc -- mysql -uroot -p"$OLD" -NBe "select 'old root still works'" 2>&1 | tail -1
sleep 60; kubectl -n pxc get pxc; kubectl -n pxc get pods | grep -E "pxc-|haproxy"
echo "== TLS: delete cluster1-ssl secret"; S0=$(kubectl -n pxc get secret cluster1-ssl -o jsonpath='{.metadata.uid}')
kubectl -n pxc delete secret cluster1-ssl; T1=$(date +%s); sleep 30
until [ -n "$(kubectl -n pxc get secret cluster1-ssl -o jsonpath='{.metadata.uid}' 2>/dev/null)" ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 600 ] && break; done; echo "SSL_SECRET_RECREATED $(( $(date +%s)-T1 ))s"
sleep 240; kubectl -n pxc get pxc; kubectl -n pxc get pods | grep -E "pxc-|haproxy"
for p in 0 1 2; do kubectl -n pxc exec cluster1-pxc-$p -c pxc -- sh -c "openssl x509 -noout -startdate -in /etc/mysql/ssl/tls.crt" 2>&1 | tail -1; done
echo "server cert presented: $(kubectl -n pxc exec cluster1-pxc-0 -c pxc -- mysql -uroot -p'CHANGE_ME_ROTATED' -NBe "show status like 'Ssl_server_not_before'" 2>&1 | tail -1)"

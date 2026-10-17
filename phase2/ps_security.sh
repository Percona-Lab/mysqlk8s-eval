echo "== root password rotation via ps-cluster1-secrets"
OLD=$(kubectl -n ps get secret ps-cluster1-secrets -o jsonpath={.data.root}|base64 -d)
kubectl -n ps patch secret ps-cluster1-secrets --type=merge -p '{"stringData":{"root":"CHANGE_ME_ROTATED"}}' >/dev/null; T0=$(date +%s)
until kubectl -n ps exec ps-cluster1-mysql-0 -c mysql -- mysql -uroot -p'CHANGE_ME_ROTATED' -NBe "select 1" >/dev/null 2>&1; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 600 ] && break; done; echo "NEW_ROOT_WORKS_AFTER $(( $(date +%s)-T0 ))s"
kubectl -n ps exec ps-cluster1-mysql-0 -c mysql -- mysql -uroot -p"$OLD" -NBe "select 'old root still works'" 2>&1 | tail -1
sleep 60; kubectl -n ps get ps; kubectl -n ps get pods | grep -E "mysql-|haproxy"
echo "== TLS: delete ps-cluster1-ssl secret"; S0=$(kubectl -n ps get secret ps-cluster1-ssl -o jsonpath='{.metadata.uid}')
kubectl -n ps delete secret ps-cluster1-ssl; T1=$(date +%s); sleep 30
until [ -n "$(kubectl -n ps get secret ps-cluster1-ssl -o jsonpath='{.metadata.uid}' 2>/dev/null)" ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 600 ] && break; done; echo "SSL_SECRET_RECREATED $(( $(date +%s)-T1 ))s"
sleep 240; kubectl -n ps get ps; kubectl -n ps get pods | grep -E "mysql-|haproxy"
for p in 0 1 2; do kubectl -n ps exec ps-cluster1-mysql-$p -c mysql -- sh -c "openssl x509 -noout -startdate -in /etc/mysql/mysql-tls-secret/tls.crt" 2>&1 | tail -1; done
echo "server cert presented: $(kubectl -n ps exec ps-cluster1-mysql-0 -c mysql -- mysql -uroot -p'CHANGE_ME_ROTATED' -NBe "show status like 'Ssl_server_not_before'" 2>&1 | tail -1)"

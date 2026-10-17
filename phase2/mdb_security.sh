echo "== password rotation via User CRD secret"
cat <<Y | kubectl -n mariadb apply -f - >/dev/null
apiVersion: v1
kind: Secret
metadata: {name: rot-user}
stringData: {password: OldPass111}
---
apiVersion: k8s.mariadb.com/v1alpha1
kind: User
metadata: {name: rot}
spec: {mariaDbRef: {name: mariadb-galera}, passwordSecretKeyRef: {name: rot-user, key: password}, host: "%"}
Y
sleep 20; kubectl -n mariadb exec probe-mariadb -- mariadb -h maxscale-galera.mariadb -urot -pOldPass111 --skip-ssl -NBe "select 'old-ok'" 2>&1 | tail -1
kubectl -n mariadb patch secret rot-user --type=merge -p '{"stringData":{"password":"NewPass222"}}'; T0=$(date +%s)
until kubectl -n mariadb exec probe-mariadb -- mariadb -h maxscale-galera.mariadb -urot -pNewPass222 --skip-ssl -NBe "select 1" >/dev/null 2>&1; do sleep 5; [ $(( $(date +%s)-T0 )) -gt 600 ] && break; done; echo "NEW_PASSWORD_WORKS_AFTER $(( $(date +%s)-T0 ))s"
kubectl -n mariadb exec probe-mariadb -- mariadb -h maxscale-galera.mariadb -urot -pOldPass111 --skip-ssl -NBe "select 'old still works'" 2>&1 | tail -1
echo "== server cert re-issue (delete secret)"; S0=$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.tls.serverCert.notBefore}'); echo "before $S0"
kubectl -n mariadb delete secret mariadb-galera-server-cert; T1=$(date +%s); sleep 60
until [ "$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.tls.serverCert.notBefore}')" != "$S0" ]; do sleep 10; [ $(( $(date +%s)-T1 )) -gt 600 ] && break; done; echo "SERVER_CERT_REISSUED $(( $(date +%s)-T1 ))s $(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.tls.serverCert.notBefore}')"
sleep 120; kubectl -n mariadb get pods | grep -E "galera|maxscale"
echo "== CA rotation (delete CA secret)"; C0=$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.tls.caBundle[0].notBefore}')
kubectl -n mariadb delete secret mariadb-galera-ca; T2=$(date +%s); sleep 60
until [ "$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = True ] && [ "$(kubectl -n mariadb get sts mariadb-galera -o jsonpath={.status.updatedReplicas})" = 3 ]; do sleep 10; [ $(( $(date +%s)-T2 )) -gt 1500 ] && break; done; echo "CA_ROTATED_READY $(( $(date +%s)-T2 ))s"
kubectl -n mariadb get mariadb mariadb-galera -o jsonpath='{.status.tls}'; echo; kubectl -n mariadb get pods | grep -E "galera|maxscale"

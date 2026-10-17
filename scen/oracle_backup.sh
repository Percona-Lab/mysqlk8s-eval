kubectl -n oracle get innodbcluster
cat <<Y | kubectl -n oracle apply -f -
apiVersion: mysql.oracle.com/v2
kind: MySQLBackup
metadata: {name: dump1}
spec: {clusterName: mycluster, backupProfileName: s3dump}
Y
T0=$(date +%s); until [[ "$(kubectl -n oracle get REDACTED dump1 -o jsonpath={.status.status})" =~ Completed|Failed|Error ]]; do sleep 3; [ $(( $(date +%s)-T0 )) -gt 1200 ] && break; done; echo BACKUP $(kubectl -n oracle get REDACTED dump1 -o jsonpath={.status.status}) $(( $(date +%s)-T0 ))s; kubectl -n oracle get REDACTED dump1 -o jsonpath='{.status}'; echo

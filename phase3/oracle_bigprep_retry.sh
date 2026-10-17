cd /root; source h.sh; OP=oracle; NS=oracle
PRI=$(kubectl -n oracle get pods -l mysql.oracle.com/cluster-role=PRIMARY -o name | cut -d/ -f2); echo primary=$PRI
sql $PRI mysql "drop database if exists sbbig; create database sbbig"
bash load.sh stop oracle >/dev/null 2>&1
T=$(date +%s); BIGDB=sbbig bash bigload.sh oracle mycluster.oracle sb SbPass123 --mysql-ssl=REQUIRED >/dev/null 2>&1
while [[ ! "$(kubectl -n oracle get pod bigprep -o jsonpath={.status.phase})" =~ Succeeded|Failed ]]; do echo "+$(( $(date +%s)-T ))s $(kubectl top pods -n oracle --no-headers | grep -E 'mycluster-[0-2]' | awk '{printf "%s=%s ",$1,$3}') restarts=$(kubectl -n oracle get pods --no-headers | grep -E 'mycluster-[0-2]' | awk '{s+=$4} END{print s}')"; sleep 60; done
echo "BIGPREP $(kubectl -n oracle get pod bigprep -o jsonpath={.status.phase}) $(( $(date +%s)-T ))s"; kubectl -n oracle logs bigprep | tail -1 | cut -c1-150
kubectl -n oracle exec $PRI -c mysql -- df -h /var/lib/mysql | tail -1; kubectl -n oracle get pods | grep -E 'mycluster-[0-2]'; kubectl -n oracle get innodbcluster
sleep 120; bash load.sh start oracle mycluster.oracle sb SbPass123 50 --mysql-ssl=REQUIRED; sleep 40; kubectl -n oracle logs load | tail -1; echo RETRY_DONE

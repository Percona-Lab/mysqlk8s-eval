cd ~/mysqlk8s
ssh -n -F ssh_config mb-cp 'cd /root; bash load.sh stop ps >/dev/null; T=$(date +%s); until [ "$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})" = ready ]; do sleep 20; [ $(( $(date +%s)-T )) -gt 5400 ] && break; done; echo "PS ready +$(( $(date +%s)-T ))s state=$(kubectl -n ps get ps ps-cluster1 -o jsonpath={.status.state})"; bash load.sh start ps ps-cluster1-haproxy.ps sb SbPass123 50 --mysql-ssl=REQUIRED >/dev/null'
CP=mb-cp STEPS="bigtrx csinodeoff" bash bin/phase3.sh ps
echo PS_RERUN3_DONE

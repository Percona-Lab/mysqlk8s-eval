cd ~/mysqlk8s
ssh -n -F ssh_config mk-cp 'cd /root; bash load.sh stop oracle >/dev/null; source h.sh; OP=oracle; NS=oracle; T=$(date +%s); until [ "$(sql mycluster-2 mysql "select count(*) from performance_schema.replication_group_members where member_state=\"ONLINE\"" 2>/dev/null)" = 3 ]; do sleep 20; [ $(( $(date +%s)-T )) -gt 5400 ] && break; done; echo "ORACLE all ONLINE +$(( $(date +%s)-T ))s"; bash load.sh start oracle mycluster.oracle sb SbPass123 50 --mysql-ssl=REQUIRED >/dev/null'
sleep 120
ssh -n -F ssh_config mk-cp "nohup bash /root/oracle_connsampler.sh 1500 > /root/oracle_conns.log 2>&1 &"
RES=phase3/results WIN=1500000 bin/run.sh oracle_p3_oneway2 oracle oracle scen/oneway.local
scp -q -F ssh_config mk-cp:/root/oracle_conns.log phase3/results/oracle_p3_oneway2_conns.log
echo ORACLE_ONEWAY2_DONE

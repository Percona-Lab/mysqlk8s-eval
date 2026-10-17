#!/bin/bash
# load.sh start|stop ns host user pass rate [extra]  -> continuous self-restarting sysbench pod "load" on mk-cp; prints "START <epoch_ms>" before each run
NS=$2
if [ "$1" = stop ]; then kubectl -n $NS delete pod load --ignore-not-found --wait=false >/dev/null; exit; fi
kubectl -n $NS delete pod load --ignore-not-found --wait=true >/dev/null
CMD="while true; do echo START \$(date +%s%3N); sysbench oltp_read_write --mysql-host=$3 --mysql-user=$4 --mysql-password=$5 --mysql-db=sbtest --tables=${TABLES:-4} --table-size=${ROWS:-500000} --threads=${THREADS:-8} --rate=$6 --time=0 --report-interval=10 --db-ps-mode=disable --mysql-ignore-errors=all ${7} run 2>&1 | grep --line-buffered -E '^\[|FATAL' ; echo EXIT \$(date +%s%3N); sleep 1; done"
kubectl -n $NS run load --restart=Never --image=perconalab/sysbench:latest --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"mk-cp"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}' --command -- bash -c "$CMD"

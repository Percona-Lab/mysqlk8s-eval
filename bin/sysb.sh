#!/bin/bash
# sysb.sh ns host user pass cmd(prepare|run) [extra]   -> runs sysbench as a pod on mk-cp
NS=$1; kubectl -n $NS delete pod sysb --ignore-not-found --wait=true >/dev/null
kubectl -n $NS run sysb --restart=Never --image=perconalab/sysbench:latest --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"'$(hostname)'"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}' --command -- sysbench oltp_read_write --mysql-host=$2 --mysql-user=$3 --mysql-password=$4 --mysql-db=sbtest --tables=4 --table-size=${ROWS:-500000} --threads=4 ${6} $5
kubectl -n $NS wait --for=jsonpath='{.status.phase}'=Succeeded pod/sysb --timeout=1800s >/dev/null; kubectl -n $NS logs sysb | tail -${TAILN:-4}

#!/bin/bash
# bigload.sh ns host user pass [extra]  -> sysbench prepare 8 x 5M rows into db sbbig (pod bigprep on mk-cp)
NS=$1; kubectl -n $NS delete pod bigprep --ignore-not-found --wait=true >/dev/null
kubectl -n $NS run bigprep --restart=Never --image=perconalab/sysbench:latest --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"'$(hostname)'"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Exists","effect":"NoSchedule"}]}}' --command -- sysbench oltp_read_write --mysql-host=$2 --mysql-user=$3 --mysql-password=$4 --mysql-db=${BIGDB:-sbbig} --tables=8 --table-size=${BIGROWS:-5000000} --threads=${BIGTHREADS:-8} $5 prepare

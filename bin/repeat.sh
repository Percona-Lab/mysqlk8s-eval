#!/bin/bash
# repeat.sh <op> <ns> <scenario-file> <count> [gap_s]  -> runs scenario N times, waiting for health between runs; RES/WIN/S env pass through
op=$1; ns=$2; scr=$3; n=$4; gap=${5:-90}; base=$(basename $scr); base=${base%%.*}
source env/$op.env; export OPENV NS=$ns; source bin/rx.sh
for i in $(seq 1 $n); do
  rx "kubectl -n $ns wait --for=condition=Ready pod -l $DBSEL --timeout=900s" >/dev/null 2>&1; sleep $gap
  echo "### ${op}_${base}_r$i"; bin/run.sh ${op}_${base}_r$i $ns $op $scr 2>&1 | grep -E "DISRUPT|no failed|LOSTCHECK|LOAD|REBUILT|ALL_DB|writer=" | cut -c1-200
done

#!/bin/bash
# run.sh <name> <ns> <probe> <scenario file>; env OPENV (helper vars), WAIT, WIN(ms), S
cd ~/mysqlk8s; RES=${RES:-results}; name=$1; ns=$2; pr=$3; scr=$4; source env/$pr.env; export NS=$ns OPENV
T=$(date +%s%3N); echo "T=$T" > $RES/$name.log
if [[ $scr == *.local ]]; then bash -c "source bin/rx.sh; source $scr"
else ssh -F ssh_config mk-cp "$OPENV; source h.sh; NS=$ns; T=$T; S=${S:-}; $(cat $scr)"; fi 2>&1 | tee -a $RES/$name.log
sleep ${WAIT:-15}
ssh -F ssh_config mk-cp "kubectl -n $ns logs probe-$pr" > $RES/probe-$pr.log
python3 bin/analyze.py $RES/probe-$pr.log $T $((T+${WIN:-300000})) | tee -a $RES/$name.log
ids=$(awk -v t=$T '$1>=t && $2=="OK"{print $4}' $RES/probe-$pr.log | tr '\n' ',' | sed 's/,$//')
[ -n "$ids" ] && ssh -F ssh_config mk-cp "$OPENV; NS=$ns; source h.sh; lostcheck '$ids'" 2>&1 | tee -a $RES/$name.log
for xp in $EXTRAPROBES; do ssh -n -F ssh_config mk-cp "kubectl -n $ns logs probe-$xp" > $RES/probe-$xp.log; echo "== extra probe $xp" | tee -a $RES/$name.log; python3 bin/analyze.py $RES/probe-$xp.log $T $((T+${WIN:-300000})) | tee -a $RES/$name.log; done
if ssh -n -F ssh_config mk-cp "kubectl -n $ns get pod load" >/dev/null 2>&1; then ssh -n -F ssh_config mk-cp "kubectl -n $ns logs load" > $RES/load-$ns.log; LS=$(ssh -n -F ssh_config mk-cp "kubectl -n $ns get pod load -o jsonpath={.status.startTime}"); python3 bin/analyze_load.py $RES/load-$ns.log $LS $T $((T+${WIN:-300000})) | tee -a $RES/$name.log; fi

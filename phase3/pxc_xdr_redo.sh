cd ~/mysqlk8s
timeout 3000 ssh -n -F ssh_config mk-cp "bash /root/pxc_xdr_a.sh" > phase3/results/pxc_xdr_a2.log 2>&1
DEST=$(awk '/^DEST/{print $2}' phase3/results/pxc_xdr_a2.log); NP=$(awk '/^NODEPORT/{printf "%s ",$3}' phase3/results/pxc_xdr_a2.log)
echo "DEST=$DEST NP=$NP"
timeout 7200 ssh -n -F ssh_config mb-cp "bash /root/pxc_xdr_b.sh $DEST $NP" > phase3/results/pxc_xdr_b2.log 2>&1
echo XDR_REDO_DONE

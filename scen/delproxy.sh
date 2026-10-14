P=$(kubectl -n $NS get pods -l $PROXYSEL -o name | head -1 | cut -d/ -f2); echo "proxy=$P"; kubectl -n $NS delete pod $P --wait=false; sleep ${S:-90}; kubectl -n $NS get pods -l $PROXYSEL -o wide

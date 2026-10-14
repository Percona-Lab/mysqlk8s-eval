W=$(writer); echo "writer=$W node=$(nodeof $W)"; kubectl -n $NS delete pod $W --wait=false; sleep ${S:-150}; kubectl -n $NS get pods -o wide | grep -v probe

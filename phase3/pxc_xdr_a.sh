# site A part: expose pods as NodePort, set source channel, take backup; prints NODEPORTS and DEST
kubectl -n pxc patch pxc cluster1 --type=merge -p '{"spec":{"pxc":{"expose":{"enabled":true,"type":"NodePort"},"replicationChannels":[{"name":"a_to_b","isSource":true}]}}}'
sleep 120; for p in 0 1 2; do echo "NODEPORT $p $(kubectl -n pxc get svc cluster1-pxc-$p -o jsonpath='{.spec.ports[?(@.port==3306)].nodePort}')"; done
cat <<Y | kubectl -n pxc apply -f -
apiVersion: pxc.percona.com/v1
kind: PerconaXtraDBClusterBackup
metadata: {name: xdrbk}
spec: {pxcCluster: cluster1, storageName: s3}
Y
T0=$(date +%s); until [[ "$(kubectl -n pxc get pxc-backup xdrbk -o jsonpath={.status.state})" =~ Succeeded|Failed ]]; do sleep 10; done; echo "XDR_BACKUP $(kubectl -n pxc get pxc-backup xdrbk -o jsonpath={.status.state}) $(( $(date +%s)-T0 ))s"; echo "DEST $(kubectl -n pxc get pxc-backup xdrbk -o jsonpath={.status.destination})"
kubectl -n pxc get secret cluster1-secrets -o json | python3 -c "import json,sys; d=json.load(sys.stdin); d['metadata']={'name':'cluster2-secrets'}; print(json.dumps(d))" > /root/xdr-secrets.json

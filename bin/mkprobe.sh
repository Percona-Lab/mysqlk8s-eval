#!/bin/bash
# mkprobe.sh name ns host user pass image [cli] [port]
N=$1; NS=$2; kubectl -n $NS delete pod probe-$N --ignore-not-found --wait=true >/dev/null
kubectl -n $NS create configmap probe-sh --from-file=probe.sh=/root/probe.sh --dry-run=client -o yaml | kubectl -n $NS apply -f - >/dev/null
cat <<Y | kubectl -n $NS apply -f -
apiVersion: v1
kind: Pod
metadata: {name: probe-$N, labels: {app: probe}}
spec:
  nodeSelector: {kubernetes.io/hostname: mk-cp}
  tolerations: [{key: node-role.kubernetes.io/control-plane, operator: Exists, effect: NoSchedule}]
  containers:
  - name: p
    image: $6
    command: [bash, /s/probe.sh]
    env: [{name: H, value: "$3"}, {name: PU, value: "$4"}, {name: PP, value: "$5"}, {name: CLI, value: "${7:-mysql}"}, {name: PORT, value: "${8:-3306}"}, {name: EXTRA, value: "${9:-}"}]
    volumeMounts: [{name: s, mountPath: /s}]
  volumes: [{name: s, configMap: {name: probe-sh}}]
Y

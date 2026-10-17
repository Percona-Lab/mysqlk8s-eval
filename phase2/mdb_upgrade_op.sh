export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "op upgrade start $(date +%s%3N)"
helm upgrade mariadb-operator-crds oci://ghcr.io/mariadb-operator/charts/mariadb-operator-crds --version 26.10.1 2>&1 | grep -E "STATUS|Error"
helm upgrade mariadb-operator oci://ghcr.io/mariadb-operator/charts/mariadb-operator --version 26.10.1 -n mariadb-system 2>&1 | grep -E "STATUS|Error"
kubectl -n mariadb-system rollout status deploy/mariadb-operator --timeout=300s >/dev/null; echo "operator rolled $(date +%s%3N)"
sleep 240; kubectl -n mariadb get mariadb,maxscale; kubectl -n mariadb get pods -o custom-columns=N:.metadata.name,IMG:.spec.containers[0].image,AGE:.metadata.creationTimestamp | grep -E "galera|maxscale"

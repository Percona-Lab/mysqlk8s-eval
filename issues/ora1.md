**Operator version:** 26.7.0-2.3.0 (deploy-crds.yaml + deploy-operator.yaml), MySQL Community 26.7.0
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
Changing `spec.mycnf` on an existing `InnoDBCluster` has no effect: the `<name>-initconf` ConfigMap is not regenerated, no rolling restart happens, and no event or status tells the user the change was ignored.

## Steps
```
kubectl -n oracle patch innodbcluster mycluster --type=merge -p '{"spec":{"mycnf":"[mysqld]\nmax_connections=333\n"}}'
```
- `kubectl get innodbcluster mycluster -o jsonpath={.spec.mycnf}` shows the new value.
- Waited 10+ min: StatefulSet not updated, pods not restarted, `SELECT @@max_connections` still 151 on all members.
- `mysqloperator/controller/innodbcluster/operator_cluster.py` has `@kopf.on.field` handlers for version, image, instances, router, TLS, logs, metrics, keyring, backupSchedules ... but none for `mycnf`.

## Expected
Either a rolling restart with the regenerated config (like the other field handlers), or a clear status/event that `mycnf` is create-only, plus a note in the docs.

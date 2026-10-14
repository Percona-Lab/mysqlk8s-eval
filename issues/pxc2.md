**Operator version:** 1.20.0
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
When a PITR restore hangs (see the companion PITR issue) and the user deletes the `PerconaXtraDBClusterRestore` to cancel it, the cluster is **not** returned to its original shape, and the restore Jobs later block namespace deletion.

## Observed
1. During restore the operator scales the cluster down. After `kubectl delete pxc-restore restore1` the cluster stays at `spec.pxc.size: 1` and `spec.haproxy.size` is unset; `kubectl get pxc` shows `ready` with PXC 1 and no HAProxy. Manual `kubectl patch pxc cluster1 --type=merge -p '{"spec":{"pxc":{"size":3},"haproxy":{"size":3}}}'` was required (cluster ready 156 s later).
2. `pitr-job-restore1-cluster1`, `prepare-job-restore1-cluster1` and `restore-job-restore1-cluster1` keep the finalizer `internal.percona.com/keep-job`. After deleting the cluster and operator, `kubectl delete ns` hung (`jobs.batch has 3 resource instances`) until the finalizers were removed by hand. Jobs of successful restores did not have this problem.
3. The orphaned pitr Job pod kept running after its Job was deleted.

## Expected
- Cancelling/deleting a restore restores the original `pxc.size`/proxy settings (or the docs describe the manual recovery).
- `keep-job` finalizers are removed when the restore is deleted, so namespaces can be cleaned up.

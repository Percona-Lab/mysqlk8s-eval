**Operator version:** 26.10.1 (Helm OCI charts), MariaDB 12.3.3, MaxScale 23.08.13-2
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
During Galera cluster recovery the operator selected the member with the **lowest** recovered seqno as bootstrap source, then failed to bootstrap it, leaving all three members in CrashLoopBackOff (full outage) until `forceClusterBootstrapInPod` was set manually.

Context: the cluster was running with a nil Galera UUID after an earlier full crash (see #1946). To clear that state all three pods were deleted at once.

## Observed
`status.galeraRecovery`:
```
{"bootstrap":{"pod":"mariadb-galera-2","time":"2026-10-14T13:09:59Z"},
 "recovered":{"mariadb-galera-0":{"seqno":18819,"uuid":"00000000-0000-0000-0000-000000000000"},
              "mariadb-galera-1":{"seqno":18822,"uuid":"00000000-0000-0000-0000-000000000000"},
              "mariadb-galera-2":{"seqno":18486,"uuid":"00000000-0000-0000-0000-000000000000"}}}
```
`mariadb-galera-2` (seqno 18486, the member whose PVC had just been re-created) was chosen, although galera-1 had 18822. Bootstrap then failed repeatedly:
```
Error reconciling Galera: error restarting Pods: error enabling bootstrap in Pod 'mariadb-galera-2': error enabling bootstrap in Pod 'mariadb-galera-2': context deadline exceeded
```
All three pods in CrashLoopBackOff for ~20 min. `forceClusterBootstrapInPod: mariadb-galera-1` -> Ready 400 s later; no acknowledged writes were lost.

## Expected
- Never pick a lower seqno than another recovered member; had this bootstrap succeeded, ~336 transactions would have been discarded.
- When all recovered UUIDs are nil (docs/galera.md says recovery cannot complete automatically then), stop and report that clearly instead of choosing a pod.

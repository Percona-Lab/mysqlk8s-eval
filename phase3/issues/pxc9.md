### Report

When the PITR binlog collector container is crash-looping, every reconcile fails in `UpdatePITRTimeline` with `exec binlog collector pod ...: unable to upgrade connection: container not found ("pitr")`, and the whole `PerconaXtraDBCluster` goes to `status.state: error`, even though all PXC and HAProxy pods are healthy (6/6 ready). Because the binlog collector Deployment is only reconciled when `status.state == ready` (`pkg/controller/pxc/backup.go:42`), a fix to `spec.backup.pitr` (e.g. a higher `timeoutSeconds`) is not applied while the collector is broken. With controller-runtime backoff, the cluster stayed in `error` and the fix stayed unapplied for 15+ minutes after the collector pod was Running again. It recovered only when I touched the CR (an annotation) to trigger a reconcile.

### More about the problem

- `CheckPITRErrors` (`pkg/pxc/backup/pitr.go:~76`) tolerates this case (`if strings.Contains(err.Error(), "container not found") { return nil }`), but `UpdatePITRTimeline` (`pitr.go:~150`) has no such handling and returns the error to the main reconcile loop.
- `collectorPod.Status.Phase` stays `Running` while the container is in CrashLoopBackOff, so the phase check doesn't protect the exec.

How the collector got there: a bulk load produced 1 GB binlogs (`max_binlog_size` default). With the default `pitr.timeoutSeconds: 60`, the upload to an S3-compatible store failed with `put object ...: context deadline exceeded` (cf. #2078 / #1847), and the pod crash-looped (50+ restarts). Meanwhile `latestRestorableTime` stopped advancing. That is the only signal in the backup status; the cluster just shows `error` with an exec message.

### Steps to reproduce

1. PXC cluster, operator 1.20.0, `backup.pitr.enabled: true`, default `timeoutSeconds: 60`, S3 storage that cannot take 1 GB in 60 s.
2. Bulk-load data so 1 GB binlogs rotate; the collector times out and crash-loops.
3. `kubectl get pxc`: STATUS `error`, condition `ErrorReconcile exec binlog collector pod ... container not found ("pitr")`.
4. Patch `spec.backup.pitr.timeoutSeconds: 600`. The `cluster1-pitr` Deployment keeps `TIMEOUT_SECONDS=60.00` until a later reconcile succeeds (here only after annotating the CR).

### Versions

1. Kubernetes: k3s v1.37.1+k3s1
2. Operator: 1.20.0 (same code on `main`)
3. Database: PXC 8.4.8-8.1

### Anything else?

Suggestions:
- Handle `container not found` / non-ready containers in `UpdatePITRTimeline` like `CheckPITRErrors` does, or treat PITR-timeline failures as a PITR condition rather than a cluster reconcile error.
- Reconcile the collector Deployment regardless of `status.state`, so PITR config fixes can be applied while it is failing.
- Raise the default `timeoutSeconds`, or make it proportional to `max_binlog_size`. Expose a clear `PITRReady=False` condition when uploads fail repeatedly.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

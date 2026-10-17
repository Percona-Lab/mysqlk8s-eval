### Report

A short I/O stall on network block storage turned into a full Group Replication outage. Kubernetes probes, not mysqld, took down all three members:

1. Right after a bulk load (sysbench prepare, 8 x 5M rows, ~16 GB) finished, the readiness (3 s) and liveness (10 s) `healthcheck` probes on the secondaries timed out while InnoDB was flushing and the secondaries were still applying the backlog.
2. kubelet killed `mysql-1` (`Container mysql failed liveness probe, will be restarted`), and `mysql-2` failed its startup probe.
3. With two members gone, the healthy primary `mysql-0` lost the majority. Its liveness check then failed by design (`in primary partition: false` -> `possible split brain!`), so it was restarted too.
4. The group was gone: `Member state: ERROR`, `Unable to join the group: peers not configured`, cluster `initializing`. The operator's crash recovery rebooted the cluster ~5 min later (`Crash recovery: Cluster was successfully rebooted`). The third member was still in `RECOVERING` (replaying the load through `group_replication_recovery`) 25+ min later.

Write probe through HAProxy: ~5 minutes of failed writes. No member actually crashed or ran out of memory; mysqld was healthy but slow.

### More about the problem

- Probe settings from the operator (1.2.0 defaults): liveness `timeoutSeconds: 10, periodSeconds: 10, failureThreshold: 3`; readiness `timeoutSeconds: 3`.
- `cmd/healthcheck/main.go` (liveness) fails when the member is not in the primary partition. That is a sensible split-brain guard for a *network* partition. But once I/O-starved secondaries have been killed by their probes, the guard restarts the last healthy member too. That converts "two members slow" into "zero members".
- Storage: Linode Block Storage CSI (network volumes, ~9 ms per 4 KB O_DSYNC write). The same dataset and load on local-path disks never triggered this. Many cloud volume types behave like this under write bursts.

### Steps to reproduce

1. PS operator 1.2.0, `group-replication`, 3 members on CSI network volumes (40Gi), `mysql` limits 3Gi, BP 1G, nodes 2 vCPU / 4 GB.
2. `sysbench oltp_read_write --tables=8 --table-size=5000000 --threads=8 prepare` through HAProxy.
3. ~1 min after prepare completes: liveness/readiness timeouts on the secondaries, restarts, the primary leaves the primary partition, full group loss.

### Versions

1. Kubernetes: k3s v1.37.1+k3s1 (Linode us-east)
2. Operator: percona-server-mysql-operator 1.2.0
3. Database: Percona Server 8.4.10-10.1

### Anything else?

Suggestions:
- Don't restart mysqld from liveness just because the member is outside the primary partition. Report it via readiness instead, and let the operator decide (e.g. after a grace period, or only when a quorum exists elsewhere).
- Make the liveness check cheaper and more tolerant: a longer timeout, or a failureThreshold that covers a typical flush/apply stall, possibly separate from the readiness timeout. Document `spec.mysql.livenessProbe` tuning for network storage.
- Expose the reason for a restart (probe vs. crash) in the CR status/events.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

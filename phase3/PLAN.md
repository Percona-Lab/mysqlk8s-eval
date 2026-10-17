# Phase 3 plan (started 2026-10-17, user: "do more tests, up to 6 more VMs"; target done by ~2026-10-21)
Infra: +2 workers mk-w4, mk-w5 (us-southeast) joined to existing k3s; +4 VMs region B (us-east): mb-cp, mb-w1..3 second k3s cluster.
Storage: Linode Block Storage CSI (StorageClass linode-block-storage) for network volumes (small volumes, pay-as-you-go).
Per operator on main cluster (PXC, PS, Oracle, MariaDB), ~0.5 day each:
 1. Deploy on CSI network volumes (3 members), ~30 GB dataset.
 2. Performance: sysbench oltp_read_write 16 and 64 threads, 5 min, via default proxy and direct to primary (proxy overhead).
 3. Network degradation on primary node: netem 100 ms delay, 5 % loss, flapping link (10 s on/off x 3 min), one-way (egress-only) partition.
 4. Awkward workloads: kill primary during open long transaction, during big ALTER on 5M-row table, during large commit.
 5. Node loss with network storage (pod reschedules + volume reattach) vs local-path.
 6. Volume expansion / storage autoscaling (PXC 1.20, PS 1.2 autoscaling; MariaDB/Oracle manual resize).
 7. Scale 3 -> 5 -> 3.
 8. Operator HA: 2 operator replicas, kill leader during failover/backup.
 9. PITR to GTID + restore into new cluster (PXC, PS); PXC ProxySQL fresh install user sync.
10. Intermittent bug reproduction rates (~10 runs): MariaDB full-crash nil UUID, Oracle delete-pod finalizer, PXC PITR first attempt.
Cross-region DR (region A -> region B) per operator: replication lag under load, switchover, failover, RPO.
Issues filed as found (self-review + dup search). Results -> report "Phase 3" section, recs doc, repo.
11. (user 2026-10-17: larger-disk VMs allowed as needed) Large dataset ~100 GB per operator on 150 Gi CSI volumes (same 4 GB nodes for comparability; resize to larger-disk plan only if volume throughput is the bottleneck): member rebuild (SST/clone) time incl. probe survival, full backup + restore throughput.
12. Perf also on local-path (CSI fsync 9 ms vs local 0.45 ms dominates).

# Phase 2 test plan (started 2026-10-14, budget <= 7 days, same 4 VMs)
Order: MariaDB -> Percona PS -> Oracle -> Percona PXC (fresh install each), then cross-cluster DR (reduced size), then report.
Per operator (~1.25 day):
 1. Install PREVIOUS operator + DB version, probe + sysbench --rate load; upgrade operator; upgrade DB (minor/major); measure outage, lost writes.
    PXC 1.19.1->1.20.0 ; PS 1.1.0->1.2.0 ; Oracle 9.7.0-2.2.8 (MySQL 9.7.0)->26.7.0-2.3.0 ; MariaDB 26.6.0->26.10.1 (+ server minor)
 2. Load ~10 GB sysbench (8 x 5M rows). Backup at scale under load (tps impact), restore into new 1-node cluster, PITR at scale where supported, scheduled backup + retention.
 3. Repeats under sustained load (sysbench --rate): delpod x3, kill9 x3, fullcrash x3, nodeoff x2; lost-write check each.
 4. Kubernetes maintenance: rolling kubectl drain + reboot of all 3 workers under load.
 5. Control plane down (k3s server stopped 5 min) + primary mysqld kill.
 6. Resource exhaustion on primary node: disk full (fallocate), memory pressure (stress-ng -> kernel OOM), CPU starvation.
 7. Security ops: TLS cert rotation, root/app password rotation via Secret.
 8. Alternative topology/proxy: MariaDB async replication + PITR; PS async+Orchestrator, PS MySQL Router; PXC ProxySQL; Oracle read replicas.
 9. Scale 3->1->3 (no extra nodes for 5).
10. Monitoring check (PMM3 vs exporters/ServiceMonitor) - light.
11. Overnight soak 8-12 h with random chaos every 30 min.
Then: cross-cluster DR with reduced sizes (PXC async replication, PS ClusterSet, Oracle ClusterSet, MariaDB multi-cluster).
Not possible on these VMs: 3->5 scaling with anti-affinity, volume expansion/autoscaling (local-path has no expansion; try TopoLVM/OpenEBS LVM only if time), cloud network storage.
Results -> new "Phase 2" sections in report doc 025f92a1-...; issues filed as found (ask? user already authorized filing bugs 2026-10-14).

**Environment:** MySQL Operator for Kubernetes 26.7.0-2.3.0 (upgraded from 9.7.0-2.2.8), MySQL Community 26.7.0, InnoDBCluster 3 instances + 3 routers, k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path storage, ~9 GB sysbench dataset, 50 tps load + 5 writes/s probe through the router. Hands-on evaluation 2026-10-15/16.

## Summary
InnoDBCluster MySQL pods get **no resource requests or limits** by default, so they are QoS `BestEffort` (`oom_score_adj 1000`). The scheduler can then pack MySQL pods onto a node regardless of memory. The kernel OOM killer picks them first, including production members.

Observed: restoring an 8.2 GB dump into a **new** 1-instance InnoDBCluster (`initDB.dump` from S3) in the same Kubernetes cluster.
- The new cluster's pod was scheduled onto the node already running production `mycluster-1`. Each mysqld uses ~3.1-3.2 GB RSS on these 4 GB nodes after loading the data.
- Kernel: `Out of memory: Killed process ... (mysqld) anon-rss:3136424kB ... oom_score_adj:1000`.
- The restore restarted. The new cluster was ONLINE only after **5,918 s**, although mysqlsh reported `Data load duration: 16 min 44 sec`.
- Production lost member `mycluster-1` (pod recreated) and had write outages of 349 s and 152 s during the restore. No acknowledged writes were lost.

## Expected
Sensible default requests (and optionally limits) for mysqld and the sidecar, derived from or documented alongside the buffer pool size, so pods are Burstable/Guaranteed and the scheduler respects node capacity. The docs should also tell users to set them. Related: #56 (podSpec changes on a live cluster are ignored), which makes adding resources after creation harder.

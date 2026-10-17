# Phase 3 progress
2026-10-17T02:23:10Z phase 3 started
2026-10-17T02:31:20Z user allowed larger-disk VMs; added 100 GB large-dataset test (CSI 150Gi)
2026-10-17T03:06:48Z PXC on CSI ready 318s, 16.1GB loaded 1748s; battery started
2026-10-17T03:29:57Z PXC perf on CSI: proxy 16th 49.9 tps p95 878ms, 64th 58.2 p95 3209; direct 16th 27.1, 64th 63.3. CSI dsync 4k write ~9 ms vs local 0.45 ms (20x) -> add local-path perf run per operator
- 2026-10-17 05:50Z PXC: netem_delay/loss 0 lost; flap 127s disruption 0 lost; oneway: 38s outage + intermittent 4s probe timeouts for ~4 min during pxc-0 rejoin (flow control), 0 lost; longtrx/ddl/ddlkill/bigtrx 0 lost; csinodeoff: pod moved+ready 436s after out-of-service taint, 0 lost; volexpand without enableVolumeExpansion = no-op; scale5 wedged -> filed pxc#2566; workaround size->3, resize 30s, then scale 5.
- SeaweedFS out of volume slots again (PITR crashloop). Old p2 backups delete blocked by permission classifier -> added 2nd volume server on 150Gi CSI PVC (phase3/s3-vol2.yaml).
- 06:00Z PXC battery done: scale 3->5 720s (after #2566 workaround), 5->3 49s; ophakill (2 op replicas, kill leader+writer) 4.8s outage, 0 lost.
- PXC cross-region DR run 1: A backup 354s, B cluster ready 335s, cross-region restore 1181s. Replica SQL stopped at first trx: 1062 dup key on :633381. xtrabackup_info "GTID of the last change ...:1-633380" but restored data already contains :633381 effects (random c column identical) -> backup GTID position off by one. Skipped 1 trx -> replication fine.
- Run 1 failover (iptables cut B<->A, promote B): B writable 38s after promote; RPO 4402 probe rows, but B had never caught up (applier ~47 tps ~= 50 tps load, backlog = 26 min backup+restore). SBS showed 0 after gtid skip (misleading). Redo with load stopped during seeding (also 2nd sample of GTID off-by-one).

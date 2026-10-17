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
- PXC local-path perf: proxy 16th 238.5 tps p95 105ms, 64th 249.9/397; direct 219.3/117, 245.3/405 => 4-8x CSI.
- PITR prefix ignored -> filed #2568. PITR type=transaction restore in region B hit 1062 + recoverer hang = our own #2558 (Phase 1); added 3/3 repro comment; #2567 cross-linked. Retrying with type=skip covering off-by-one + bad trx.
- Volume expansion on Linode CSI v1.1.4: PVC/Linode volume grow, kubelet says FileSystemResizeSuccessful, but guest block device stays old size (rescan no effect) -> known linode CSI #67; commented. Earlier 40->50Gi "success" was not real at fs level. Rolling Linode reboot fixes (fs 148G). My reboot script overlapped reboots (stale Ready check) -> 2/3 PXC down, ~160s outage, auto-recovered, 0 lost.
- PITR type=skip (gtid :753797:789296 = off-by-one + bad delete) into fresh region-B cluster: Succeeded 2029s (base restore cross-region + 361 binlogs); 17016 deleted rows restored, markers before+after present. type=transaction blocked by #2558.
- 100GB load started 13:19Z (sbhuge 8x40M) on PXC CSI 150Gi.
- ProxySQL fresh install (region B): all 3 pods had new app user within ~30s, 6/6 logins OK for 20 min -> #2565 is specific to HAProxy->ProxySQL switch.
- 100GB load: binlogs on datadir with 30-day expiry (49G after 1h) would overflow 148G -> set binlog_expire_logs_seconds=3600 (rec: size PVC for binlogs or lower expiry when PITR uploads them). PITR collector 1GB binlog upload hit default timeoutSeconds 60 -> crashloop; cluster state=error via UpdatePITRTimeline exec; timeout fix not applied until reconcile poke -> filed #2569.
- Linode CSI installed in region B (helm v1.1.4, us-east); scripts parameterized with CP=${CP:-mk-cp}; PS Phase 3 runs in region B.
- 14:29Z PS region B: after 16GB bigprep, probe timeouts killed secondaries, primary liveness 'not in primary partition' -> full GR loss; crash recovery rebooted 14:34; mysql-2 RECOVERING 25+ min via binlog replay. Filed ps#1659. Battery auto-starts when ready (CP=mb-cp).
- PS region B: mysql-2 RECOVERING 95+ min with 50 tps load (applier slower than incoming; mysql-1 ONLINE but ~7.6k trx queue; GR flow control threshold 25000 not reached). Stopped load to let it catch up.
- PXC 100GB: load 8x40M 6721s; backup #1 killed by runningDeadlineSeconds while stuck in Starting (98.75GB uploaded) -> comment on #2564; backup #2 Succeeded 2161s (~46MB/s); in-place restore Succeeded 3026s (restore 838s, prepare 61s, cluster start/SST 2066s); 40M rows verified, sbhuge 69GB.
- PXC Phase 3 DONE 2026-10-17 ~17:30Z. Tearing down PXC on main cluster.
- Oracle: mk-w2 node thrashed (no mem limits on Oracle pods; primary+operator on w2 during 8-thread bulk load) -> NotReady, eviction; rebooted. podSpec resources can't be changed after creation (documented in CRD) -> recreated cluster with mysql limit 3Gi.
- partition.sh had main-cluster IPs only -> PS flap/oneway in region B invalid (no effect); regenerated with all 20 IPs, rerun PS flap+oneway.
- Oracle run2 (3Gi limit): bigprep 8 threads -> all 3 mysqld OOMKilled (BP 1G) -> NO_QUORUM; operator force_quorum after ~1 min, ONLINE within ~14 min. Recreating with MALLOC_ARENA_MAX=2 (same as PS).
- Oracle run3: MALLOC_ARENA_MAX=2 + GR cache 128M still OOM at 3Gi; secondaries ~3.05GiB RSS at rest with BP 1G (instrumented ~1.5GB, anon 3.2GB -> ~1.7GB uninstrumented, like PS #1652). Set BP 512M on Oracle (others 1G) to fit 3Gi.
- PS ddlkill: failover 157s, then cascade of probe kills (5/6/3 restarts) + HAProxy liveness (select 1 via own frontend) -> all HAProxy CrashLoopBackOff; writes back ~4 min after primary ONLINE. bigtrx/csinodeoff ran on broken cluster -> rerun. Comment added to ps#1659.
- Oracle run4 BP 512M: 16GB load 853s, but mycluster-1 OOMKilled during load; idle RSS 2.7-3.0Gi with 512M BP (~2GB uninstrumented). Battery started 18:50Z.
- Oracle oneway (egress-block writer mk-w3 90s): writes down 1307s (21.8 min). Routers: stop RW 19:29:01-08, resume 19:29:18-28 (still old primary); GR failover 19:30:55, routers saw mycluster-2 RW 19:30:50; 19:37:46 mycluster-2 "Too many connections (1040)" -> routers can't refresh metadata/auth until 19:50:42; probe 'Can't connect mycluster.oracle:3306 (111)'. TODO rerun with processlist sampling.
- Oracle flap: 180s disruption, 0 lost.
- PS volexpand: PVCs not 50Gi after 1204s (FS still 40G) - investigate.
- PS volexpand wedge -> filed ps#1660; workaround enableVolumeExpansion+size 3, then size 5 re-requested.

# Progress log
2026-10-14T15:15:28Z phase 2 started; plan written
2026-10-14T15:32:37Z MariaDB: upgrade op 26.6.0->26.10.1 (MaxScale rolling, 2x3s, 0 lost; MaxScale image stays 23.08.5); DB 11.8.8->12.3.3 + MaxScale 23.08.13 (2.9+2.5s, 0 lost)
2026-10-14T15:46:30Z MariaDB: 10GB sbbig prepared in 723s (after fixing User maxUserConnections=10 default)
2026-10-14T16:24:05Z MariaDB: 8.9GB physical backup (bzip2, target Replica) 1614s, no tps impact, 0 failed writes; bootstrap new 1-node cluster 598s, data verified
2026-10-14T16:47:04Z MariaDB: kill9 repeat batch INVALID (two batch processes ran concurrently -> double kill); delpod repeats r1-3 ran without load (1.4/8.9/2.5s + 8.9s second blip)
2026-10-14T17:38:00Z MariaDB repeats: delpod 6.5/6.1/4.8s; kill9 r1 15.2s(+stalls) r2 154.7s FULL-CLUSTER RECOVERY after single kill (finding)
2026-10-14T19:13:06Z MariaDB repeats done: kill9 r3 8.2s; fullcrash 16.6/184/8.3s, nil UUID in 2 of 3; nodeoff rejoin failed both runs -> total outage until forced bootstrap (353s). 0 lost writes.
2026-10-14T19:54:04Z MariaDB drain run INVALID: in-guest reboot leaves Linode offline (watchdog disabled); w1+w2 offline. Fixed drain to use Linode API reboot. Note: mk-w1 galera-1 did not become Ready within 900s after w1 drain/reboot (pod Terminating 0/2) - recheck
2026-10-14T21:50:34Z MariaDB batch2: drain all 3 workers (API reboot) 1.5+4.7s blips, 0 lost; cpdown: writes continued (probe DNS blips on cp = harness artifact), DB Ready ~10.5 min after k3s restart; diskfull: DiskPressure True 4 min, no eviction of DB?, blips <=4.5s; OOM: 0.9s; CPU starvation: 12s+4.5s, min tps 8. 0 lost everywhere.
2026-10-14T23:57:59Z MariaDB: galera-2 stuck since OOM test (startup probe kills 9GB SST); CR probe change not propagated; manual sts patch -> rejoin 1293s; CR stuck NotReady until operator restart. Security test rerun.
2026-10-15T00:14:18Z MariaDB security: server cert reissue 60s rolling, CA rotation 92s rolling, blips<=7.7s, 0 lost; password rotation ignored unless Secret labelled k8s.mariadb.com/watch (then 7s)
2026-10-15T00:32:05Z MariaDB scale: replicas=1 rejected by webhook for Galera (design)
2026-10-15T01:09:20Z MariaDB async repl: PITR OK (73s) but archive interval 10min fixed; kill9 failover 2.1s/0 lost; old primary errant GTID can't rejoin; node-off no failover (434s outage); binlog archival error after crash
2026-10-15T01:09:37Z MariaDB soak 6h started (random delpod/kill9/delproxy/cpu every ~30min)
2026-10-15T07:31:07Z MariaDB soak 6h: 11 events, availability 99.962%, 0 lost; cluster healthy
2026-10-15T08:18:49Z PS 1.1.0 installed (resource fixes: limit 3Gi, BP 1G, GR cache 128M; 3 findings); probe+load running
2026-10-15T08:26:38Z PS upgrade: op 1.1->1.2 no disruption; CR 1.2.0 + PS 8.4.10 rolling 236s, max 10.5s, 0 lost
2026-10-15T09:00:08Z PS: GR OOMs under bulk insert traced to glibc malloc fragmentation (jemalloc shipped but not loaded); MALLOC_ARENA_MAX=2 fixed; 9.3GB loaded
2026-10-15T11:40:36Z PS: 9.3GB backup 232s; in-place PITR jobs ~6 min, correct cut; stuck 2h due to group_replication_* option breaking --initialize of new members (finding); config header finding
2026-10-15T12:55:58Z PS repeats: delpod 2.3/10.6/2.5s; kill9 25.3/26.9/21.9s; fullcrash 139/209/362s (growing); nodeoff 49/54s rejoin 114/89s; 0 lost
2026-10-15T13:33:20Z PS batch2: drain 4.4+11.5s; cpdown 25.9s (failover w/o API), ready 33s after API back; diskfull 5s; oom/cpu 0s; 0 lost
2026-10-15T13:40:42Z PS security OK (root pw 6s, TLS regen 30s rolling); binlog server crash loop after rebuilds (finding), reset prefix
2026-10-15T14:07:32Z PS router: kill9 28.7/21.4s, delpod 1.3s, delproxy 0; switching haproxy->router: CR typo left endpoint pointing at non-existent router (error state) briefly. PS soak 6h started (router)
- report doc phase2 pending block id: mqtxd7e5ssj.31538 (body node a102336a-b2fd); issue drafts ~/mysqlk8s/phase2/issues (not yet filed - asked user)
2026-10-15T14:59:31Z User authorized filing bugs as found (no review needed, self-review first). Filed: mariadb-operator #1958-#1961 + #1946 comment; percona-server-mysql-operator #1649-#1653; k8sps-docs #277
2026-10-15T20:13:48Z PS soak 6h: availability 99.393%, 0 lost of 78978; single kill9 -> operator deleted all pods (357s outage) = #1478, commented
2026-10-15T20:41:13Z PS async+orchestrator: kill9 5.7/7.3s, delpod 13.2s, nodeoff 54.5s failover OK rejoin 122s, 0 lost. PS done.
2026-10-15T21:00:49Z Oracle upgrade: op 2.2.8->2.3.0 no disruption; MySQL 9.7.0->26.7.0 (+router) 423s, blips 2.5+1.4s, 0 lost
2026-10-15T22:52:40Z Oracle: dump 8.2GB 157s; restore to new cluster 5918s (OOM, BestEffort pods), prod outages 349+152s during restore (finding)
2026-10-16T00:59:58Z Oracle repeats: delpod r1 36.7s; stuck finalizer -> 84 min outage (finding); single retest OK; relaunched repeats
2026-10-16T01:00:37Z filed mysql/mysql-operator Phase2 issues (see filed.txt)
2026-10-16T02:09:21Z Oracle repeats: delpod 1.1/1.6s; kill9 22.4/22.2/21.9s; fullcrash 36.8/51.4/126.8s; nodeoff 52.6/45.0s rejoin 100/114s; 0 lost
2026-10-16T02:54:43Z Oracle batch2: drain blips 0.6/2.7/1.1s; cpdown 22.6s; diskfull/oom/cpu 0; 0 lost
2026-10-16T03:31:32Z Oracle: root pw rotation via Secret ignored; read replica Ready while empty, catch-up ~25 min; soak 6h started
- PXC phase scripts ready: phase2/pxc_install_old.sh, pxc_setup.sh, pxc_upgrade.sh, pxc_bigbackup.sh
2026-10-16T09:51:53Z Oracle soak 6h: 99.727%, 0 lost, only scheduled events. Oracle done.
2026-10-16T10:25:40Z PXC 1.19.1 installed (needed to drop forcePathStyle/prefix not in 1.19 CRD)
2026-10-16T10:34:33Z PXC upgrade: op 1.19.1->1.20.0 none; CR 1.20 + PXC 8.4.8 rolling 266s, worst 15.4s, 0 lost
2026-10-16T10:44:49Z PXC 9GB loaded in 604s, ~0.9GiB/member, no restarts
2026-10-16T13:34:10Z PXC 9GB: backup 167s; in-place PITR restore 678s, outage 316s, correct cut (0 rows after target, marker2 absent, table restored); lost=818 = expected rollback after target
2026-10-16T14:51:32Z PXC repeats: delpod 0/0/0; kill9 4.7/6.7/2.7s; fullcrash 126/163/296s UUID valid; nodeoff 51.9/47.8s rejoin 133/132s; 0 lost
2026-10-16T15:32:56Z PXC batch2: drain 3x0.6s; cpdown 16.2s; diskfull 2.8s; oom/cpu 0; 0 lost
2026-10-16T16:17:05Z PXC security: root pw 6s; ssl secret regen 30s (client cert from ssl-internal unchanged). ProxySQL switch: user sync bug (#2565); after pod recreate kill9 4.5/4.5s, delpod/delproxy 0. PXC soak 6h started (proxysql)
- report Phase 2 section written (heading .31539, table repeats .33117 has PXC soak '*running*' cell to update)
2026-10-16T22:38:51Z PXC soak 6h: 99.987%, 0 lost. Starting DR tests.
2026-10-16T22:53:31Z PXC DR: replica site (1 node) via backup 219s + restore 260s, channel lag 0 within 61s; site1 paused -> promote cluster2 writable in 5s; 0 of 89795 acked writes missing (graceful stop)
2026-10-16T23:44:47Z PS ClusterSet DR: bootstrap 83s; planned switchover 9s; forced failover blocked while primary DNS unresolvable (#1658), happened only when old primary pod returned; replica INVALIDATED
2026-10-16T23:56:33Z Oracle ClusterSet (undocumented, works in Community): replica cluster 41s; switchover 5s; forced failover with old primary isolated 14s; router follows primary; isolated old primary stays writable (no fencing); 0 lost of 477
2026-10-17T00:28:59Z MariaDB multi-cluster DR: replica member crashloop (GTID 1236); documented switchover -> both writable, new primary missing 2275 acked rows (#1965). DR tests done.
MON: PXC+PMM3 auto-registered mysql+haproxy (ready 103s); PS+PMM3 same (72s); Oracle metrics sidecar needs user image; operator writes socket=unix:///... -> mysqld-exporter >=0.15 mysql_up 0 (known #61), v0.14.0 works
MON: MariaDB metrics.enabled without Prometheus Operator CRDs -> no exporter created, CR Ready, error only in logs (commented on #1961). Monitoring checks done.

**Environment:** percona-server-mysql-operator 1.2.0 (upgraded from 1.1.0), Percona Server 8.4.10-10.1, group replication, 3 members + HAProxy/Router, binlog server 0.3.1 (PITR), k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path, ~9.3 GB sysbench dataset, 50 tps load. Hands-on evaluation 2026-10-15.

## Summary
Any `group_replication_*` option in `spec.mysql.configuration` (we used `group_replication_message_cache_size=134217728` to cut memory) works on running members. But it makes **new members fail to initialize**, because the GR plugin is not loaded during `mysqld --initialize`:
```
[ERROR] [MY-000067] [Server] unknown variable 'group_replication_message_cache_size=134217728'.
[ERROR] [MY-013455] [Server] The newly created data directory /var/lib/mysql//mysql-tmpdir/ by --initialize is unusable.
[ERROR] [MY-010119] [Server] Aborting
```
This surfaced after an in-place PITR restore: the restore/pitr jobs completed at 09:31, but the cluster stayed `initializing` with 1 member for ~2 h. mysql-1 was in CrashLoopBackOff (25 restarts), and `PerconaServerMySQLRestore` stayed `Running` with no error. Prefixing the option with `loose-` fixed it immediately.

## Expected
Strip or `loose-`-prefix GR options during initialize (or document it), and fail the restore with a clear status instead of staying `Running`.

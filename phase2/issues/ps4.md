**Environment:** percona-server-mysql-operator 1.2.0 (upgraded from 1.1.0), Percona Server 8.4.10-10.1, group replication, 3 members + HAProxy/Router, binlog server 0.3.1 (PITR), k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path, ~9.3 GB sysbench dataset, 50 tps load. Hands-on evaluation 2026-10-15.

## Summary
Under sustained write load (sysbench prepare, 4-8 threads, multi-row INSERTs) the mysqld containers grow far beyond what performance_schema accounts for. They are OOM-killed, several members within minutes of each other, which takes the group down:
```
VmRSS 3128240 kB, RssAnon 3085160 kB      (limit 3Gi)
performance_schema total 1711 MB  (buf_buf_pool 1047, GCS_XCom::xcom_cache 128, certification_info 92, ...)
```
About 1.4 GB of anonymous memory is uninstrumented, a glibc malloc fragmentation pattern. The image ships `/usr/lib64/libjemalloc.so.2`, but mysqld does **not** load it (0 jemalloc mappings in `/proc/<pid>/maps`). Setting `env: MALLOC_ARENA_MAX=2` on the mysql container fixed it: the same 9.3 GB load completed with no restarts.

Related sizing notes:
- 1.1.0 defaults (mysql 2Gi request/4Gi limit; HAProxy pod 2Gi with mysql-monit) don't fit three 4 GB nodes.
- After lowering requests, SmartUpdate waited on Pending HAProxy pods ("Waiting for HAProxy to be ready before smart update") until they were deleted by hand.
- With a 2Gi limit the auto-config sets `innodb_buffer_pool_size` to 50 % of the limit but leaves `group_replication_message_cache_size` at 1 GiB, so all members OOM together.

## Expected
Load jemalloc (LD_PRELOAD) or set MALLOC_ARENA_MAX by default; size the GR message cache together with the buffer pool; let SmartUpdate proceed when pods are Pending.

**Operator version:** 26.7.0-2.3.0, MySQL 26.7.0
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
A backup profile with an S3 prefix that starts with `/` works for backups, but the same style of prefix in `initDB.dump.storage.s3.prefix` makes the new cluster crash-loop with a misleading error. The InnoDBCluster only shows `PENDING`.

## Steps
1. Backup profile: `dumpInstance.storage.s3: {bucketName: oracle, prefix: /dumps, config: s3-config, endpoint: http://s3.s3.svc:9000}`. `MySQLBackup` completes: output `dump1-20261014-112411`, objects stored under `dumps/dump1-20261014-112411/` (`@.json`, `@.done.json`, ... all present).
2. New cluster with `initDB.dump.storage.s3.prefix: /dumps/dump1-20261014-112411` (same bucket/config/endpoint).

## Observed
`restored-0` sidecar:
```
mysqlsh.Error: Shell Error (53029): Dump directory is corrupted, some of the metadata files are missing
sidecar [CRITICAL] Unhandled exception while bootstrapping MySQL ...
```
Pod in CrashLoopBackOff; `kubectl get innodbcluster` shows `PENDING` with no reason. With `prefix: dumps/dump1-20261014-112411` (no leading slash) the restore works (2.01 M rows loaded in 24 s, cluster ONLINE in 99 s).

## Expected
Normalise the prefix consistently for backup and restore (or reject a leading slash), report "dump not found at <bucket>/<prefix>" rather than "corrupted", and surface initDB failures in the InnoDBCluster status.

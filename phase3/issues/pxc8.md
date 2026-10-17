### Report

`spec.backup.storages.<name>.s3.prefix` (added in #2382 / K8SPXC-1679) is honored by full backups but ignored by the PITR binlog collector and by the PITR restore. Binlogs, `gtid-binlog-cache.json` and `last-binlog-set-*` are written to the bucket root instead of `<bucket>/<prefix>/`.

### More about the problem

- Full backups use `BackupStorageS3Spec.BucketAndPrefix()`, which appends `b.Prefix`. They land in `s3://pxc/p3/cluster1-...-full`, as expected.
- The binlog collector (`pkg/pxc/app/binlogcollector/binlog-collector.go:261`) and the restore's `BINLOG_S3_BUCKET_URL` (`pkg/pxc/backup/restore.go:699/707`) use `BucketURL()`, which returns only the bucket (or the endpoint path) and never looks at `b.Prefix`.

Observed with `bucket: pxc, prefix: p3`: `fs.ls /buckets/pxc/p3` lists 0 binlog objects, while the bucket root has 498 `binlog_*` objects plus `gtid-binlog-cache.json` and `last-binlog-set-<uuid>` from this cluster and from older clusters that used other prefixes.

Consequences:
- The prefix is the documented way to share one bucket between clusters or environments. With it, the binlogs of all clusters still end up mixed in one location, and they share and overwrite a single `gtid-binlog-cache.json`.
- Lifecycle/retention rules or IAM policies scoped to `<prefix>/` don't cover the binlogs. Cleaning up a cluster's prefix leaves its binlogs behind.
- The behavior differs from the docs and from the `prefix` field description.

PITR restore currently works only because restore and collector make the same mistake.

### Steps to reproduce

1. Operator 1.20.0. In the S3 storage set `bucket: pxc`, `prefix: p3`, `forcePathStyle: true`, and enable `backup.pitr` with `storageName` pointing at it.
2. Take a backup and let PITR upload binlogs.
3. List the bucket: the backup is under `p3/`, but the binlogs and the cache file are at the root.

### Versions

1. Kubernetes: k3s v1.37.1+k3s1
2. Operator: 1.20.0 (same code on `main`)
3. Database: PXC 8.4.8

### Anything else?

Fix: use `BucketAndPrefix()` (bucket + prefix) for the collector's `S3_BUCKET_URL` and the restore's `BINLOG_S3_BUCKET_URL`. Consider a compatibility fallback that also reads the bucket root for existing setups.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

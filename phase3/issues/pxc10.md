### Proposal

With `backup.pitr.enabled: true`, binlogs are uploaded to object storage every `timeBetweenUploads`, but they also stay on the PXC data volume for the server default `binlog_expire_logs_seconds = 2592000` (30 days). Under a write-heavy workload this can fill the data PVC.

Observed (operator 1.20.0, PXC 8.4.8): during a 100 GB bulk load (sysbench prepare 8 x 40M rows), 49 GB of binlogs accumulated on each node within about 1 hour. The 150 Gi datadir would have filled before the load finished. I had to `SET PERSIST binlog_expire_logs_seconds=3600` on all nodes by hand.

Suggestions:
- When PITR is enabled, default `binlog_expire_logs_seconds` to something proportional to the upload interval (e.g. a few hours), or let the collector purge binlogs it has uploaded.
- Otherwise, document that binlog retention must be sized against the PVC and surface a warning/condition when binlogs exceed a share of the volume.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

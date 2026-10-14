**Operator version:** 1.20.0 (deploy/bundle.yaml + deploy/cr.yaml, PXC 8.4.8-8.1, XtraBackup 8.4.0-5.1)
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
A PITR restore (`pitr.type: date`) from a full backup taken while the cluster was receiving writes failed while replaying binlogs with a duplicate key error. The PITR process then **did not exit**: the restore stayed in `Point-in-time recovering` indefinitely, and the cluster was left with 1 PXC pod and no HAProxy (full outage) until manual intervention.

## Steps to reproduce
1. 3-node cluster, HAProxy, `backup.pitr.enabled: true` (timeBetweenUploads 60) to S3.
2. Run a light write load (one INSERT every 200 ms into an auto-increment table via HAProxy).
3. Take an on-demand backup (`PerconaXtraDBClusterBackup`, succeeded in 66 s).
4. Insert a marker row, note the time T, insert another row, drop a table. Wait ~150 s for binlog upload.
5. Restore: `backupName: backup1`, `pitr: {type: date, date: "<T>", backupSource: {storageName: s3}}`.

## Observed
pitr job log:
```
recovery type: date, target time: 2026-10-14 08:37:33 +0000 UTC
Checking sub result  binlog gtid  5475792c-...:11445-11697  sub result  5475792c-...:1-11444
working with binlog_1791967009_000044_..., 3 out of 3 remaining
Running /usr/bin/sh -c mysqlbinlog --disable-log-bin --stop-datetime="2026-10-14 08:37:33" -
ERROR 1062 (23000) at line 1559: Duplicate entry '29292' for key 't.PRIMARY'
```
- On the restored node: `@@gtid_executed = 5475792c-...:1-11498`, but row 29292 (written by the transaction **after** GTID 11498) is already present. The backup's data is ahead of its recorded GTID set, so replay re-applies a transaction that is already in the data.
- Inside the pitr pod: `/opt/percona/pitr recover` still running, its `mysql` child `<defunct>`. The Job stays active, the operator logs `Waiting for restore job to finish` every 5 s, the restore never reaches `Failed`.
- Cluster stays at `PXC 1`, no HAProxy pods.

Two later attempts with fresh backups (same load) restored correctly in 365 s, so this is intermittent, likely a race between the backup's GTID position and in-flight commits.

## Expected
- Backup GTID set consistent with the data (or PITR replay tolerant of already-applied GTIDs).
- If replay fails, the PITR process exits, the restore goes to `Failed` with the error, and the cluster is not left at size 1.

Related: deleting the stuck restore does not revert the cluster spec (separate issue).

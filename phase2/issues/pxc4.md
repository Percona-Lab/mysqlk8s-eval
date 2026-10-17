**Environment:** percona-xtradb-cluster-operator 1.20.0 (upgraded from 1.19.1), PXC 8.4.8-8.1, XtraBackup 8.4.0-5.1, 3 PXC + 3 HAProxy, PITR enabled, S3-compatible storage (SeaweedFS, HTTP), k3s v1.37.1, ~9 GB dataset, 50 tps load. Hands-on evaluation 2026-10-16.

## Summary
Three backup-robustness problems seen together after the S3 endpoint temporarily stopped accepting writes (our object store ran out of volume slots):

1. **A backup can stay `Running` for hours with no error.** xbcloud kept retrying with 5-minute sleeps:
   ```
   xbcloud: Operation failed. Error: Timeout was reached
   xbcloud: Sleeping for 300000 ms before retrying p2/cluster1-.../sbbig/sbtest7.ibd.00000000000000000027 [9]
   ```
   After storage recovered, the job produced no further output and the `PerconaXtraDBClusterBackup` stayed `Running` for 2.5 h. The CR has `runningDeadlineSeconds: 1200`, but it only seems to apply to the job *starting*. Nothing bounds a hung upload, and the status never shows the storage error.
2. **Deleting the backup CR leaves its job running.** After `kubectl delete pxc-backup bigbk2` the CR was gone, but job `xb-bigbk2` and its pod kept running until deleted by hand.
3. **Re-using the backup name fails immediately.** Creating a new `bigbk2` while the old `xb-bigbk2` job was still terminating failed after 15 s with `Backup didn't start running in runningDeadlineSeconds, failing the backup` / `running deadline seconds exceeded`. The deadline was apparently measured from the old job's start time.

A fresh backup with a new name then succeeded (167 s for ~9 GB), and an in-place PITR from it restored exactly to the target time.

## Expected
- A deadline/stall detection for the running upload, with the xbcloud error surfaced in `status`.
- Deleting a backup CR also deletes (or at least stops) its job.
- New backups are not judged by a previous job with the same name.

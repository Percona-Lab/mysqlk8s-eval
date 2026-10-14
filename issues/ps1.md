**Operator version:** 1.2.0 (Percona Server 8.4.10-10.1, GR, binlog server 0.3.1)
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
The sample `deploy/backup/restore.yaml` shows the PITR date in RFC 3339 form, which the operator rejects.

`deploy/backup/restore.yaml` (v1.2.0):
```yaml
#    date: "2024-11-18T11:10:48Z"
#    type: date
```
Restore with `pitr: {type: date, date: "2026-10-14T10:18:48Z"}` goes straight to Error:
```
reconcile pitr config: search binlogs: search binlogs: exec binlog_server search_by_timestamp: stdout: {"version":1,"status":"error","message":"Invalid timestamp format"}
```
The same restore with `date: "2026-10-14 10:18:48"` (the format used on https://docs.percona.com/percona-operator-for-mysql/ps/backups-restore-pitr.html) succeeded in 263 s with correct data.

## Expected
Fix the sample (and ideally accept RFC 3339 too, since it is the natural Kubernetes format; or validate in the CRD/webhook with a clear message).

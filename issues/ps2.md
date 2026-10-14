**Operator version:** 1.2.0 (binlog server image percona/percona-server-mysql-operator:1.2.0-binlog-server-0.3.1, `logLevel` default)
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
With PITR enabled, the binlog server logs every replicated event at `info` level, several lines per transaction:
```
[2026-10-14T10:18:04.568911] [   info] event  : query (suppress_use)
[2026-10-14T10:18:04.568925] [   info] event  : table_map
[2026-10-14T10:18:04.568937] [   info] event  : write_rows
[2026-10-14T10:18:04.568946] [   info] event  : xid
[2026-10-14T10:18:04.568952] [   info] event  : [end_of_transaction] 47184353-...:5479
```
At a modest 5 tx/s this is ~25 log lines/s; at production write rates it will flood the log pipeline. `logLevel: info` is the cr.yaml default.

## Expected
Per-event logging at `debug`/`trace`; `info` should report file rotations, uploads and errors.

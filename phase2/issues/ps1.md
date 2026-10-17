**Environment:** percona-server-mysql-operator 1.2.0 (upgraded from 1.1.0), Percona Server 8.4.10-10.1, group replication, 3 members + HAProxy/Router, binlog server 0.3.1 (PITR), k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path, ~9.3 GB sysbench dataset, 50 tps load. Hands-on evaluation 2026-10-15.

## Summary
The sample `deploy/cr.yaml` and the docs (https://docs.percona.com/percona-operator-for-mysql/ps/options.html, "Use a ConfigMap / custom configuration" example) show `spec.mysql.configuration` **without** a `[mysqld]` group header:
```yaml
configuration: |-
  max_connections=250
  innodb_buffer_pool_size={{containerMemoryLimit * 3/4}}
```
mysqld accepts this file, but every backup then fails. The xtrabackup sidecar reads the same file and aborts:
```
xtrabackup: [ERROR] Found option without preceding group in config file /etc/mysql/config/my-config.cnf at line 1.
xtrabackup: [ERROR] Fatal error in defaults handling. Program aborted!
sidecar.create backup  failed waiting for xbcloud to finish  {"error": "signal: killed"}
```
The backup Job retried 7 times and went to `Failed` after 674 s. The `PerconaServerMySQLBackup` status shows only `state: Failed`, with no reason.

## Expected
Either the operator writes the user configuration under a `[mysqld]` group (or validates it), or samples and docs include the header. Backup status should carry the error.

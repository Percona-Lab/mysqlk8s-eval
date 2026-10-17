Found during hands-on testing of Percona Operator for MySQL (PS) **1.2.0** on 2026-10-15.

The custom configuration example on https://docs.percona.com/percona-operator-for-mysql/ps/options.html (and the commented sample in `deploy/cr.yaml`) has no `[mysqld]` group header:
```yaml
configuration: |
  max_connections=250
```
mysqld accepts this, but the xtrabackup sidecar reads the same file (`/etc/mysql/config/my-config.cnf`) and aborts with `Found option without preceding group in config file ... at line 1`, so **every backup fails**. Please add `[mysqld]` to all examples and note that the header is required (operator issue filed separately). The later example on the same page (with `innodb_buffer_pool_size={{containerMemoryLimit * 3 / 4}}`) does include `[mysqld]`, so the two examples are inconsistent.

Related doc gap: options containing `group_replication_*` in `configuration` break initialization of new members unless prefixed with `loose-`. Worth a warning on the same page.

**Environment:** percona-xtradb-cluster-operator 1.20.0, PXC 8.4.8-8.1, ProxySQL image from 1.20.0 cr.yaml (proxysql2 2.7.x), 3 PXC + 3 ProxySQL, k3s v1.37.1, 50 tps load. Hands-on evaluation 2026-10-16.

## Summary
After switching a running cluster from HAProxy to ProxySQL (`haproxy.enabled: false`, `proxysql.enabled: true`), the cluster reported `ready` in 72 s. But for **20+ minutes only 1 of 3 ProxySQL pods had the application users**, so about 2 of 3 client connections through `cluster1-proxysql` failed with:
```
ERROR 1045 (28000): ProxySQL Error: Access denied for user 'probe'@'10.42.0.59' (using password: YES)
```
`runtime_mysql_users` counts per pod were 16 / 6 / 10. `admin-cluster_mysql_users_diffs_before_sync` is `0`, so ProxySQL's own cluster sync of users is disabled, and every pod depends on the operator's resync. That resync kept failing:
```
ERROR sync users  exec syncusers: ... ERROR (line:515) : The cluster (with writer hostgroup:11) has not been configured in ProxySQL
ERROR sync users  syncusers: ERROR 1045 (28000) at line 1: ProxySQL Admin Error: UNIQUE constraint failed: mysql_users.username, mysql_users.frontend
                  ERROR (line:718) : Failed to add the user (xtrabackup) from PXC to ProxySQL database.
```
The pxc-monit sidecars also logged `UNIQUE constraint failed: proxysql_servers.hostname, proxysql_servers.port`. Deleting proxysql-1 and -2 fixed it: the recreated pods had all 16 users within ~3 min.

## Expected
The cluster should not report `ready` until every ProxySQL pod has the users, and the resync should be idempotent (`INSERT OR REPLACE`/delete-then-insert) so a failed first sync heals itself. Enabling ProxySQL user sync between ProxySQL cluster members would also avoid per-pod drift.

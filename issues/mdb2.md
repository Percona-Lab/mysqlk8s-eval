**Operator version:** 26.10.1, MariaDB 12.3.3, 3-replica Galera
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
A logical `Restore` (from a `Backup` with default `ignoreGlobalPriv: true`) into a running Galera cluster rewrites the `mysql` privilege tables. They are Aria tables, which Galera does not replicate: the DDL reaches every member but the rows exist **only on the member that executed the restore**. The other members lose all grants in `mysql.db`/`mysql.tables_priv`, including the `mariadb.sys` rows that the `mysql.user` view needs. This stays invisible until the next restart, then applications fail on 2 of 3 members.

## Steps
1. Galera cluster with `User`/`Grant`/`Database` CRs (`probe`, `sb`).
2. `Backup` logical1 to S3 (Success), then `Restore` `backupRef: logical1` into the same cluster (Success, 85 s).
3. Any rolling restart, e.g. change `spec.myCnf`.

## Observed
```
mariadb-galera-0 db-rows=2 engine=Aria
mariadb-galera-1 db-rows=0 engine=Aria
mariadb-galera-2 db-rows=0 engine=Aria
```
- After the restart: `ERROR 1142 (42000): INSERT command denied to user 'probe'@... for table probe.t` via MaxScale and the primary Service (application outage, ended only by copying the privilege tables by hand with `wsrep_on=0`).
- On galera-1/2: `select count(*) from mysql.user` -> `ERROR 1356 (HY000): View 'mysql.user' references invalid table(s) ...`
- Grant CRs stayed `READY True / Created`. Deleting them hung: the finalizer fails with `error checking if user exists in MariaDB: Error 1356 ... View 'mysql.user' references invalid table(s)`.
- Also by design but worth a warning: the restore runs online with no fencing, so rows written after the backup were overwritten (442 acknowledged writes in this run).

## Expected
Exclude the `mysql` system schema from logical restores into Galera (or restore grants via SQL statements/the SQL CRDs), document the Galera limitation, and let Grant/User reconciliation detect missing privileges.

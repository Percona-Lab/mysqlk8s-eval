### Report

When a replica-site cluster is seeded by restoring a backup of the source cluster (the documented cross-site replication setup), the restored `gtid_executed` is one transaction behind the data. The `replicationChannels` replica then re-applies a transaction that is already in the data and stops with error 1062 (duplicate key). Reproduced 2 out of 2 times.

### More about the problem

Run 1 (source under ~50 tps sysbench plus a probe writer):
- Backup `xtrabackup_info`: `binlog_pos = filename 'binlog.000025', position '198', GTID of the last change '<uuid>:1-633380'`
- Restored cluster: `gtid_executed = <uuid>:1-633380`
- Replica error: `Worker 1 failed executing transaction '<uuid>:633381' ... Could not execute Write_rows event on table sbtest.sbtest4; Duplicate entry '336539' for key 'sbtest4.PRIMARY', Error_code: 1062`
- The source binlog shows that `:633381` is the only event touching `sbtest4.id=336539` in the last 30 binlogs: a plain INSERT, so the row did not exist before it. The restored row has the same random `c` value as the source, so the effects of `:633381` were already in the backup.

Run 2 (fresh backup, only a ~3 writes/s probe writer, no sysbench):
- `xtrabackup_info`: `binlog_pos = filename 'binlog.000026', position '198', GTID of the last change '<uuid>:1-753796'`
- Replica error: `Worker 1 failed executing transaction '<uuid>:753797' ... Write_rows event on table probe.t; Duplicate entry '122528' for key 't.PRIMARY', Error_code: 1062`

In both runs the backup's recorded GTID set is exactly one transaction behind its InnoDB data. Both times `binlog_pos` is at position 198 of a just-rotated binlog on the donor. That suggests the GTID set is captured at the binlog rotation/backup lock while one more Galera-applied transaction is already committed in InnoDB.

Skipping the transaction with an empty `gtid_next` transaction let replication continue. That is only safe because I verified the transaction was already applied. Users following the docs would see a broken replica right after setup. Worse, if the off-by-one transaction were an UPDATE (no duplicate-key error), it could be silently applied twice (e.g. `k=k+1`), which would diverge the replica without any error.

### Steps to reproduce

1. Site A: PXC 3 nodes, operator 1.20.0, `replicationChannels: [{name: a_to_b, isSource: true}]`, `expose` NodePort, constant writes.
2. Take a `PerconaXtraDBClusterBackup` to S3.
3. Site B (separate k8s cluster): create a cluster with the same secrets and restore that backup with `PerconaXtraDBClusterRestore` (`backupSource.destination`).
4. Configure `replicationChannels: [{name: a_to_b, isSource: false, sourcesList: [...site A NodePorts...]}]`.
5. `SHOW REPLICA STATUS` shows `Replica_SQL_Running: No`, error 1062 on the first transaction after the restored `gtid_executed`.

### Versions

1. Kubernetes: k3s v1.37.1+k3s1 (two clusters, Linode us-southeast and us-east)
2. Operator: 1.20.0
3. Database: Percona XtraDB Cluster 8.4.8-8.1 (WSREP 26.1.4.3), backup image percona/percona-xtrabackup:8.4.0-5.1

### Anything else?

This may belong to PXB/PXC (Jira), but it surfaces through the operator's cross-site replication workflow, so I'm filing it here first. I can provide full binlog excerpts.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

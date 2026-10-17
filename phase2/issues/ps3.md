**Environment:** percona-server-mysql-operator 1.2.0 (upgraded from 1.1.0), Percona Server 8.4.10-10.1, group replication, 3 members + HAProxy/Router, binlog server 0.3.1 (PITR), k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path, ~9.3 GB sysbench dataset, 50 tps load. Hands-on evaluation 2026-10-15.

## Summary
With the PITR binlog server enabled, after a series of member restarts/rebuilds during our failure tests (rolling node drain, control-plane outage, disk-full and OOM tests, and earlier an in-place PITR restore) the binlog server crash-loops indefinitely:
```
[error] std::system_error caught: cannot fetch binlog event: Cannot replicate because the source purged required binary logs. Replicate the missing transactions from elsewhere, or provision a new replica from ...
```
Consequences:
- Binlog collection stops, so PITR silently loses coverage.
- `kubectl get ps` shows `STATE initializing` / `Ready=False` indefinitely, although all 3 MySQL members are ONLINE. The operator loops on `reconcileUsers Waiting cluster to be ready`, which blocks other reconciliation.

Recovery needs a manual change of the binlog storage prefix (fresh collection), as described for the 0.3.1 upgrade.

## Expected
Detect the purged-position condition and start a fresh collection automatically (requiring/creating a new full backup), report it in status, and don't block cluster Ready on the binlog server.

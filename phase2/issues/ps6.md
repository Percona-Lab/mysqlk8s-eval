**Environment:** percona-server-mysql-operator 1.2.0, Percona Server 8.4.10-10.1, two GR clusters in one namespace (`ps-src` 3 members, `ps-rep` 1 member, `bootstrap.mode: manual`) joined in a `PerconaServerMySQLClusterSet` (`createReplicaClusterOptions.recoveryMethod: clone`), k3s v1.37.1. Hands-on evaluation 2026-10-16.

## Summary
Forced failover never happens when the primary cluster's endpoint **no longer resolves in DNS**, which is the normal state when the primary site is actually down.

Steps:
1. ClusterSet bootstrapped fine (replica ready in 83 s); a planned switchover to `psrep` worked (writable in 9 s, old primary `super_read_only=1`).
2. Simulated loss of the new primary site: `kubectl patch ps ps-rep -p '{"spec":{"pause":true}}'`. All `ps-rep` pods gone, so `ps-rep-mysql-0.ps-rep-mysql.ps.svc.cluster.local` no longer resolves.
3. `kubectl patch ps-clusterset ps-dr -p '{"spec":{"primaryCluster":"pssrc","unsafeFlags":{"forcedFailover":true}}}'`

Result: after 15 min `pssrc` was still REPLICA / `super_read_only=1`. Status:
```
type: Ready  status: Unknown  reason: ClusterSetManagerError
message: ping, stdout: , stderr: ... MySQL Error 2005: No such host is known 'ps-rep-mysql-0.ps-rep-mysql.ps.svc.cluster.local'
```
The operator logged `Reconciler error` for psclusterset-controller every second.

## Cause (from source, v1.2.0 and main @ f5ce74c)
`pkg/clusterset/manager/manager.go` (`getClusterSetManager`) only treats `mysqlsh.ErrEndpointUnreachable` as "try next endpoint / unreachable". Error 2005 (unknown host) falls into `NewGenericError`. `pkg/controller/psclusterset/controller.go` calls `reconcileForcedFailover` only when `csmanager.IsUnreachableError(err)`, so the forced-failover path is never reached.

## Expected
Treat DNS resolution failures (2005) and similar connection errors as unreachable, so `forcedFailover: true` can promote the surviving cluster. An e2e test that removes the primary cluster's pods/Service (not just blocks traffic) would cover this.

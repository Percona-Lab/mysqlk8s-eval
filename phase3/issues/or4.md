### Summary

After a member restart, the operator cannot rejoin the member while the cluster is `ONLINE_PARTIAL`. Every rejoin attempt fails because the operator's MySQL Shell call is refused for a cluster that belongs to an InnoDB ClusterSet but is not ONLINE. The cluster can't return to ONLINE without the rejoin, so it stays `ONLINE_PARTIAL` (2/3) indefinitely. The operator retries every ~14 minutes with the same error.

Operator 2.3.0 (`26.7.0-2.3.0`), server 26.7.0. The cluster was created as a plain `InnoDBCluster` (no `initDB`/ClusterSet spec). The routers nevertheless log `Target cluster(s) are part of a ClusterSet`, i.e. the operator creates a ClusterSet by default.

### Observed

- `mycluster-0` (formerly PRIMARY) was killed while it was the writer (pod deleted together with the operator leader, as part of an operator-HA test). The pod came back and mysqld is up with `super_read_only=1`, but GR member state is `OFFLINE`. The other two members are ONLINE.
- `kubectl get innodbcluster` shows `ONLINE_PARTIAL 2/3` for 2+ hours (and counting).
- Operator log, every ~14 min:
```
[ERROR] pod=mycluster-0 endpoint=mycluster-0.mycluster-instances.oracle.svc.cluster.local:3306 ...
error=Shell Error (51314): This function is not available through a session to an InnoDB Cluster that belongs to an InnoDB ClusterSet but is not ONLINE diagnose_instance: get_cluster error
```
- `on_pod_create` runs again on each retry, but the rejoin never happens.

### Expected

The operator should handle the "ClusterSet member cluster that is not ONLINE" case. For example, open the shell session on the current PRIMARY of the cluster (which is ONLINE) and call `get_cluster()` there, or use `dba.get_cluster()` through a session to an ONLINE member and `rejoin_instance()`. A single member restart should not leave the cluster degraded until manual intervention.

### Environment

k3s v1.37.1+k3s1, 3 x InnoDBCluster members on Linode Block Storage CSI volumes, 3 routers, ~16 GB dataset, 50 tps sysbench load. Found during a hands-on evaluation of MySQL operators (https://github.com/Percona-Lab/mysqlk8s-eval).

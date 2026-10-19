### Summary

After an egress-only network partition of the PRIMARY's node (90 s), writes through MySQL Router stayed down for ~22 minutes, although Group Replication failed over in ~2 minutes. The new primary ran out of connections (`Too many connections (1040)`), and the routers could not refresh metadata/auth from it until ~20 minutes later. Seen in 1 of 2 runs; the rerun recovered in 42 s. Filing because the failure mode is severe and the logs are clear.

### Timeline (operator 2.3.0 / server + router 26.7.0, 3 instances, 3 routers, 50 tps sysbench through `mycluster:3306`)

- 19:28:52 egress from mycluster-0's node blocked (iptables OUTPUT/FORWARD DROP to all cluster IPs) for 90 s.
- 19:29:01–08: all 3 routers `Stop accepting connections for routing routing:bootstrap_rw`, `Target cluster(s) are part of a ClusterSet: not accepting RW connections`.
- 19:29:18–28: routers `Start accepting connections` again, metadata still showing mycluster-0 as PRIMARY.
- 19:30:50–55: routers see `mycluster-2 ... mode=RW`; operator logs `PRIMARY changed for oracle/mycluster`.
- 19:37:46: router `Failed connecting with Metadata Server mycluster-2...: Too many connections (1040)`, then `Fetching the auth credentials from metadata failed`.
- 19:50:42: router `Connected with metadata server running on mycluster-2`. Writes resume (first successful probe write +1307 s after the cut).
- Clients saw `ERROR 2003 Can't connect to MySQL server on 'mycluster.oracle:3306' (111)` for the whole period.

`max_connections` was the default 151. The workload was 4 sysbench threads + 1 probe (new connection every 200 ms), so the connection pile-up on the new primary was not caused by client concurrency.

### Expected

Router/operator should not let a failover end in connection exhaustion on the new primary, e.g. by closing stale/hung routed connections, or the operator reserving connections for router metadata/auth. A metadata-refresh path that needs a free connection should not be able to lock routers out for 20 minutes.

### Environment

k3s v1.37.1, Linode 4 GB nodes, Linode Block Storage CSI volumes, ~16 GB dataset. Hands-on operator evaluation: https://github.com/Percona-Lab/mysqlk8s-eval (phase3/results/oracle_p3_oneway.log, oracle_p3_oneway2*.log).

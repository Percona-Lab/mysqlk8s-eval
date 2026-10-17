**Environment:** MySQL Operator for Kubernetes 26.7.0-2.3.0, MySQL 26.7.0, InnoDBCluster 3 instances + 3 routers, ~9 GB data, 50 tps load, k3s v1.37.1. Hands-on evaluation 2026-10-16.

Two smaller day-2 gaps:

1. **Root password rotation is not supported.** We changed `rootPassword` in the cluster's `secretName` Secret (`mypwds`). After 600 s the new password still didn't work and the old one did. No event or status says the change is ignored. The docs don't describe a rotation procedure either, so users have to `ALTER USER` by hand and keep the Secret in sync themselves.

2. **A new read replica is Ready while far behind.** We added `spec.readReplicas: [{name: rr, instances: 1}]` to the running cluster. `mycluster-rr-0` was `2/2 Ready` after 41 s, but it had been provisioned (nearly) empty and was replaying the full binlog history: `probe.t` had 74 rows vs 59,386 on the primary, `sbbig.sbtest1` 406,912 of 5,000,000. It caught up after ~25 min. MySQL Router's read-only port did not route to it in our test, but anyone using the replica's own Service reads stale data, and readiness gives no hint of the lag. Provisioning via clone (as for group members) and lag-aware readiness would help. Related to #47 (read replica reconcile / NotReady handling).

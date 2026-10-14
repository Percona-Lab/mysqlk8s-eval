Found during a documentation review of Percona Operator for MySQL (Percona Server) **1.2.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Missing / misleading HA content
1. There is no page on recovering a Group Replication cluster after a full-cluster outage. Only `mysql.autoRecovery` in the CR reference and the status conditions exist; PXC has a full crash-recovery page. In our test (all three mysqld killed at once) the operator recovered automatically in ~122 s; documenting what autoRecovery does, how long it takes and what to do when it is off/fails would help.
2. https://docs.percona.com/percona-operator-for-mysql/ps/features.html says "Automatic failover with intelligent primary election handled by the Orchestrator". For Group Replication (the GA, default topology) failover is GR-native; Orchestrator is used only for async replication (tech preview).

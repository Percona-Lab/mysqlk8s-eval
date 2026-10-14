Reproduced the same end state on **26.10.1** with **MariaDB 12.3.3**, triggered differently (all three `mariadbd` processes `kill -9`'d at once, nodes stayed up), plus what it leads to later.

Environment: k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path, 3-replica Galera + 3 MaxScale (23.08.13-2), `tls.enabled: true`, default recovery settings.

1. Writes resumed in 15 s. `mariadb-galera-1` log:
   ```
   12:18:07 WSREP: Found saved state: 0334b073-c7c6-11f1-ac90-87f023d3c438:-1, safe_to_bootstrap: 0
   12:18:19 WSREP: clear restored view
   12:18:19 WSREP: Bootstrapped primary 00000000-0000-0000-0000-000000000000 found: 3.
   ```
   Afterwards on all members: `wsrep_local_state_uuid` empty, `wsrep_cluster_state_uuid` 00000000-..., `Primary`/`Synced`, `grastate.dat` uuid 0000.../seqno -1. MariaDB CR `Ready=True`.
2. **Latent impact:** ~6 min later one worker was hard powered off for 6 min. After boot the member never rejoined: every mariabackup SST ends with
   ```
   WSREP: Failed to parse uuid:seqno pair: ':17904'
   WSREP: SST succeeded for position 00000000-0000-0000-0000-000000000000:-1
   WSREP: Receiving IST failed, node restart required: IST receiver reported failure: 'IST started with wrong seqno: 17693, expected <= 0'
   ```
   then the startup probe kills it -> CrashLoopBackOff for 15+ min. Deleting that member's `storage-` PVC did not help (the donor itself has no UUID).
3. Restarting all three pods to clear it led to a full outage: recovery chose the wrong bootstrap pod and timed out (filed separately as #1956). Setting `forceClusterBootstrapInPod` to the highest-seqno pod brought the cluster back with a new UUID after 400 s; total write outage ~22 min, no acknowledged writes lost.
4. A second identical full crash on the repaired cluster kept its UUID (`Found saved state: fc3599a0-...:-1` ... recovered in 116 s), so it is intermittent for us too.

Suggestion: never report `Ready`/`GaleraReady` while `wsrep_cluster_state_uuid` is the nil UUID, and treat that state as needing recovery.

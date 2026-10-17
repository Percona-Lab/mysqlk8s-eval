**Environment:** MySQL Operator for Kubernetes 26.7.0-2.3.0 (upgraded from 9.7.0-2.2.8), MySQL Community 26.7.0, InnoDBCluster 3 instances + 3 routers, k3s v1.37.1, 3 workers (2 vCPU / 4 GB), local-path storage, ~9 GB sysbench dataset, 50 tps load + 5 writes/s probe through the router. Hands-on evaluation 2026-10-15/16.

## Summary
During repeated "delete the primary pod" tests, one deleted pod was **never recreated**. `mycluster-1` (deleted 23:11:53 UTC) stayed Terminating with finalizer `kopf.zalando.org/KopfFinalizerMarker` and its containers exited (pod phase `Succeeded`). The group failed over correctly (writes back after 37 s), but the cluster then ran on 2 of 3 members with no replacement. A later delete of the new primary left 1 of 3, so quorum was lost and writes were down for **84 minutes**, until the finalizers were removed by hand.

Operator loop while stuck (repeating):
```
on_pod_deleted: mycluster-2 pod.phase=Succeeded cluster.instances=3 online=[]  primary=None  cluster_state=ClusterDiagStatus.OFFLINE
on_pod_deleted: mycluster-2 ATTEMPTING CLUSTER REPAIR
Handler 'on_pod_delete' failed temporarily: Cluster cannot be restored because there are unreachable pods
Patching failed with inconsistencies: (('remove', ('status', 'kopf'), {'progress': {'on_pod_delete': {'started': '2026-10-15T23:33:43...', 'stopped': No...
```
The InnoDBCluster showed `OFFLINE 0/3`. This is a deadlock: the operator won't repair because pods are "unreachable", and the pods can't come back because the operator holds their finalizers. After removing the finalizers, the operator ran `reboot_cluster_from_complete_outage` and the cluster was ONLINE 237 s later, with no acknowledged writes lost (5,275 checked).

A single delete-pod retest right afterwards recreated the pod normally (~77 s incl. the 120 s grace period), so this is intermittent. The operator pod had been replaced ~13 min before the first stuck deletion, during a node-memory-pressure episode (separate issue on missing resource requests), and the log is full of kopf "Patching failed with inconsistencies" warnings on `status.kopf.progress.on_pod_delete`. Earlier operator logs were lost with that restart.

## Expected
The pod-delete handler must not block pod recreation indefinitely. The finalizer should be released (or the handler time out) when the instance can't be removed cleanly, and repair should treat Terminating/Succeeded pods as replaceable.

### Report

Same root cause as percona/percona-xtradb-cluster-operator#2566, also present in `percona-server-mysql-operator` 1.2.0 (`pkg/controller/ps/volumes.go`). If `spec.mysql.volumeSpec...storage` differs from the StatefulSet's `volumeClaimTemplates` while fewer pods exist than `spec.mysql.size`, the cluster goes to `error`:

```
reconcile: database: ensure component: failed to ensure statefulset: patch ps/ps-cluster1-mysql:
StatefulSet.apps "ps-cluster1-mysql" is invalid: spec.volumeClaimTemplates: Invalid value: [... "storage":"50Gi" ...]
```

Once that has happened, the operator can neither resize nor scale. `status.state: error` persisted for 90+ minutes (Reconciler error every ~16 min with back-off), and a later `size: 5` never created pods.

### More about the problem

`reconcilePersistentVolumes()` returns early on `len(podList.Items) < int(cr.Spec.MySQL.Size)`. That return comes before the branch that, with `enableVolumeExpansion` off, restores the configured size (`cr.Spec.MySQL.VolumeSpec...Requests[storage] = configured`). The StatefulSet is then patched with the new size and rejected by the API server.

In my run the window was opened by a node loss rather than a scale-up: a mysql pod was being rescheduled after its node was powered off and tainted `node.kubernetes.io/out-of-service`. The storage request was changed (40Gi -> 50Gi, expansion not enabled) during that window, and the next step (`size: 5`) kept `pods < size` true permanently.

### Steps to reproduce

1. PS operator 1.2.0, group replication, 3 members, CSI StorageClass with `allowVolumeExpansion: true`; leave `enableVolumeExpansion` unset.
2. Delete one mysql pod (or lose its node) and, while it is being recreated, patch `spec.mysql.volumeSpec.persistentVolumeClaim.resources.requests.storage` to a larger value. Or patch storage and `spec.mysql.size: 5` together.
3. The CR goes to `error` with the StatefulSet `volumeClaimTemplates` error; scaling/resizing stays blocked.

### Versions

1. Kubernetes: k3s v1.37.1+k3s1
2. Operator: percona-server-mysql-operator 1.2.0
3. Database: Percona Server 8.4.10-10.1

### Anything else?

Same suggested fix as #2566 in the PXC operator: don't skip the "keep configured size" logic when pods < size, and never send a changed `volumeClaimTemplates` to an existing StatefulSet.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

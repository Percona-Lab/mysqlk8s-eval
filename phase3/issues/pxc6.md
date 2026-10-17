### Report

Scaling up `spec.pxc.size` while `spec.pxc.volumeSpec...storage` differs from the StatefulSet's volumeClaimTemplate puts the cluster into a permanent `error` state. The operator can then neither scale nor resize, and setting `enableVolumeExpansion: true` afterwards does not recover it.

### More about the problem

In `pkg/controller/pxc/volumes.go`, `reconcilePersistentVolumes()` returns early when there are fewer pods than requested:

```go
if len(podList.Items) < int(cr.Spec.PXC.Size) {
    return false, nil
}
```

That return comes before both of the paths that would protect the StatefulSet:
- with `enableVolumeExpansion: false`, the path that restores the configured size: `cr.Spec.PXC.VolumeSpec...Requests[storage] = configured`
- with `enableVolumeExpansion: true`, the resize / orphan-delete-sts path

The reconciler then calls `updatePod` with the new storage size in `volumeClaimTemplates`, and the API server rejects it:

```
failed to deploy pxc: updatePod for pxc: failed to create or update sts: update error: StatefulSet.apps "cluster1-pxc" is invalid: spec.volumeClaimTemplates: Invalid value: ...
```

The scale-up never happens (pods stay at 3 because the sts update fails), so `len(pods) < size` stays true and the early return repeats on every reconcile. The cluster is stuck.

The same line is still on `main`.

### Steps to reproduce

1. Deploy operator 1.20.0 with a 3-node PXC cluster (crVersion 1.20.0) on an expandable StorageClass (Linode block storage CSI, `allowVolumeExpansion: true`). Leave `enableVolumeExpansion` unset.
2. Increase the storage request, e.g. 40Gi -> 50Gi. Nothing happens, which is expected with expansion disabled. The cluster stays `ready`.
3. Patch `spec.pxc.size: 5`.
4. The cluster goes to `error` with the sts error above. No new pods are created.
5. Patch `enableVolumeExpansion: true`. The cluster is still in `error` and the PVCs are not resized.
6. Workaround: patch `spec.pxc.size: 3`. The resize to 50Gi completes in under 30s, the sts is re-created, and state returns to `ready`. Scaling to 5 then works.

The same deadlock should also occur with expansion enabled if size and storage are changed in the same patch.

### Versions

1. Kubernetes: k3s v1.37.1+k3s1
2. Operator: percona/percona-xtradb-cluster-operator:1.20.0
3. Database: PXC 8.4 (operator default)

### Anything else?

Suggested fix: do not skip the "keep configured size" / resize logic when pods < size. Alternatively, apply the template size from the existing sts whenever the resize branch is skipped, so a pending storage change can never block unrelated reconciliation such as scaling.

Found during a hands-on operator evaluation (https://github.com/Percona-Lab/mysqlk8s-eval).

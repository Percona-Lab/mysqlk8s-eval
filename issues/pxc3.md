**Operator version:** 1.20.0 (`backup.pitr` enabled, image percona/percona-xtrabackup:8.4.0-5.1 for the collector)
**Environment:** k3s v1.37.1+k3s1, 1 tainted control-plane + 3 workers (Linode 2 vCPU / 4 GB, Ubuntu 24.04.4), local-path storage, S3-compatible object store (SeaweedFS, HTTP). Found during a hands-on operator evaluation on 2026-10-14.

## Summary
The PITR binlog collector Deployment (`cluster1-pitr`) used **1111 MiB** of memory (`kubectl top pods`) while the cluster was nearly idle (one small INSERT every 200 ms, 0.5 GB dataset). Each PXC pod used ~510 MiB at the same time, HAProxy 14 MiB. The cr.yaml has no default requests/limits for `backup.pitr.resources`, so on small nodes this single pod can push a node into memory pressure.

```
cluster1-pitr-647596bfc4-b2q7z   6m   1111Mi
cluster1-pxc-0                   60m   513Mi
```
Measured once, after ~1 h of uploads every 60 s.

## Expected
Collector memory bounded (streaming upload rather than buffering?), and sensible default requests/limits in cr.yaml.

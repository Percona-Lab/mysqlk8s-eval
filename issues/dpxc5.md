Found during a documentation review of Percona Operator for MySQL (PXC) **1.20.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Broken links (404, checked with curl)
- Tag format missing the `v` prefix: `https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/1.20.0/deploy/cr.yaml` (data-source.md); `https://github.com/percona/percona-xtradb-cluster-operator/blob/1.20.0/deploy/backup/restore.yaml` (backups-move-from-external-db.md)
- `https://github.com/percona/percona-operator/issues` and `/pulls` (index.md)
- `https://docs.percona.com/everest/quickstart-guide/quick-install.html` (what-next.md)
- `https://docs.percona.com/percona-server/latest/rotating-master-key.html` (encryption.md)
- `https://docs.percona.com/percona-xtradb-cluster/8.0/install/index.html` (backups-move-from-external-db.md)
- `https://docs.percona.com/percona-xtrabackup/innovation-release/{xtrabackup-option-reference,xbstream-options,xbcloud-options}.html` (operator.md)
- `https://docs.percona.com/percona-server/innovation-release/proxy-protocol-support.html` (haproxy-conf.md)
- `https://proxysql.com/compare` (architecture.md)
- `https://github.com/kubernetes/kube-state-metrics/blob/main/docs/customresourcestate-metrics.md`

Also: the nav links "Building and testing the Operator" and "Contributing" are pinned to `v1.18.0` (mkdocs-base.yml).

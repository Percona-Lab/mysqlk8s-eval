Found during a documentation review of Percona Operator for MySQL (Percona Server) **1.2.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Quickstart problems
1. https://docs.percona.com/percona-operator-for-mysql/ps/kubectl.html expected output lists 3 CRDs; the v1.2.0 bundle has 4 (`perconaservermysqlclustersets.ps.percona.com` is missing). The step also omits `--server-side`, unlike minikube.html and the PXC docs.
2. https://docs.percona.com/percona-operator-for-mysql/ps/helm.html: the customised `helm install my-db percona/ps-db --set ...` example omits `--namespace`, so it installs into `default` although the text says it deploys into my-namespace.
3. The quickstart overview promises a "logical backup"; the operator takes physical XtraBackup backups.
4. The repo sample `deploy/backup/restore.yaml` uses `date: "2024-11-18T11:10:48Z"`, which the operator rejects (`Invalid timestamp format`); the docs page format `2026-03-20 09:15:00` works. (Operator issue filed separately.)

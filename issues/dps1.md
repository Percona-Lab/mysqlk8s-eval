Found during a documentation review of Percona Operator for MySQL (Percona Server) **1.2.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Problems on https://docs.percona.com/percona-operator-for-mysql/ps/users.html
1. It runs the client with `--image=percona:8.4` (twice). That tag does not exist on Docker Hub, so the pod fails with ImagePullBackOff. `percona/percona-server:8.4` works.
2. It hard-codes `-proot_password`, while the root password is generated into the `<cluster>-secrets` Secret; show how to read it (`kubectl get secret ps-cluster1-secrets -o jsonpath='{.data.root}' | base64 -d`).
3. Worth stating explicitly that declarative users are not available in 1.2.0 (users must be created in SQL).

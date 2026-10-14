Found during a documentation review of Percona Operator for MySQL (PXC) **1.20.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Problems on the kubectl / Helm quickstart
1. https://docs.percona.com/percona-operator-for-mysql/pxc/kubectl.html "Expected output" for bundle.yaml lists 4 CRDs including `perconaxtradbbackups.pxc.percona.com`, which does not exist (the bundle has 3). With `--server-side` kubectl prints `serverside-applied`, not `created`. The CR output contains a stray space: `perconaxtradbcluster.pxc.percona.com/ cluster1`.
2. The page offers Minikube as a prerequisite but deploys the full cr.yaml, which needs 3 schedulable nodes (hostname anti-affinity on PXC and HAProxy). No pointer to cr-minimal.yaml there.
3. The default cr.yaml enables a daily backup to a PVC (`fs-pvc` schedule); the quickstart doesn't mention it.
4. helm.html pins no `--version`; the repo already serves chart pxc-operator 1.20.1 (appVersion 1.20.0), so installs drift from the docs.
5. Typos/confusion on kubectl.html: "Install not already installed"; the intro says the operator is for "Percona Server for MySQL" (it is PXC).

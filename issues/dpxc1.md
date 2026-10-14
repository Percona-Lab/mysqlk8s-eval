Found during a documentation review of Percona Operator for MySQL (PXC) **1.20.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Problem
The connectivity step in every platform install guide runs the client as:
```
kubectl run -i --rm --tty percona-client --image=percona:8.4 --restart=Never -- bash -il
```
The tag `percona:8.4` does not exist on Docker Hub (the official `percona` image tags stop at 8.0.x / 9.7.x), so the pod goes to ImagePullBackOff and the first thing an evaluator tries fails.

Affected pages (shared fragment `assets/fragments/connectivity.txt`): gke.html, eks.html, aks.html, minikube.html, openshift.html, kubernetes.html, e.g. https://docs.percona.com/percona-operator-for-mysql/pxc/gke.html

## Fix
Use an image that exists and matches the server, e.g. `percona/percona-xtradb-cluster:8.4` or `percona/percona-server:8.4` (verified working).

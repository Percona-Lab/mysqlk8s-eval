# MySQL-compatible Kubernetes operators: documentation review

Review date: 2026-10-14. This is a documentation-only review (no servers were touched).
Sources: the live doc sites, shallow clones of the docs and operator repos, and the GitHub API, Docker Hub API and Helm index files.

| # | Operator | Version reviewed | Docs reviewed |
|---|---|---|---|
| 1 | Percona Operator for MySQL based on PXC | 1.20.0 | https://docs.percona.com/percona-operator-for-mysql/pxc/ (repo percona/k8spxc-docs @ b58e7cc, 2026-10-09; 131 pages) |
| 2 | Percona Operator for MySQL (Percona Server; GR + async) | 1.2.0 | https://docs.percona.com/percona-operator-for-mysql/ps/ (repo percona/k8sps-docs @ e9f2a92, 2026-10-12; 104 pages) |
| 3 | Oracle MySQL Operator for Kubernetes | 26.7.0-2.3.0 | https://dev.mysql.com/doc/mysql-operator/en/ (25 pages, 8 chapters) + release notes https://dev.mysql.com/doc/relnotes/mysql-operator/en/ |
| 4 | mariadb-operator (community) | 26.10.1 | GitHub markdown only: https://github.com/mariadb-operator/mariadb-operator/tree/main/docs (repo @ e071201, 2026-10-07; 30 topic pages + generated API ref) |

How to read the markings:
- **[V]** means I checked it against the source, a manifest or an API.
- **[D]** means the docs state it but I did not check it further.
- **[U]** means it is unverified or inferred.
- On the Percona sites, the `main` branch of the docs repo is ahead of the published site. For example, k8sps-docs `main` already mentions 1.3.0 user CRDs and TLS changes, but the live site does not. Every defect below was checked against the live published page unless it says otherwise.

---

## 0. Repository facts (GitHub API, 2026-10-14) [V]

| | PXC operator | PS operator | Oracle mysql-operator | mariadb-operator |
|---|---|---|---|---|
| Repo | percona/percona-xtradb-cluster-operator | percona/percona-server-mysql-operator | mysql/mysql-operator | mariadb-operator/mariadb-operator |
| Stars / forks | 624 / 213 | 232 / 45 | 947 / 167 | 1,027 / 214 |
| Open issues (excl. PRs) | 36 (63 incl. PRs) | 14 (32 incl. PRs) | 13 (14 incl. PRs) | 149 (212 incl. PRs) |
| Contributors (GitHub users / incl. anonymous) | 73 / 87 | 33 / 34 | 13 / 16 | 79 / 88 |
| Operator license | Apache-2.0 | Apache-2.0 | UPL 1.0 (LICENSE file; GitHub shows NOASSERTION) | MIT (Copyright MariaDB plc) |
| DB image license | PXC GPLv2; images on Docker Hub (percona/*) | PS GPLv2; Docker Hub | MySQL Community GPLv2 (container-registry.oracle.com/mysql/community-*); Enterprise images need an Oracle subscription | MariaDB Server GPLv2 (docker.io `mariadb`); **MaxScale is BSL 1.1** (docs/maxscale.md warns about this) |
| Last 5 releases | 1.20.0 2026-06-05; 1.19.1 2026-04-16; 1.19.0 2026-01-19; 1.18.0 2025-08-14; 1.17.0 2025-04-14 | 1.2.0 2026-07-03; 1.1.0 2026-04-17; 1.0.0 (GA) 2025-11-17; 0.12.0 2025-09-23; 0.11.0 2025-09-01 | 26.7.0-2.3.0 2026-07-31; 9.7.0-2.2.8 2026-04-24; 9.6.0-2.2.7 2026-01-21; 9.5.0-2.2.6 2025-10-22; 9.4.0-2.2.5 ~2025-07 (release-notes dates; GitHub has tags only, no Releases) | 26.10.1 2026-09-21; 26.10.0 2026-09-18; 26.6.0 2026-06-06; 26.3.0 2026-03-13; 25.10.4 2026-01-08 |
| Cadence | About every 4 months; occasional patch release | About every 2.5–5 months | Quarterly, tied to MySQL releases; from 26.7 a single version line | Quarterly (YY.MM) plus fast patch releases |
| Helm charts | percona/pxc-operator 1.20.1 (appVersion 1.20.0, 2026-09-07); pxc-db 1.20.0 | ps-operator 1.2.0; ps-db 1.2.0 | mysql-operator / mysql-innodbcluster 2.3.0. **The index.yaml keeps only the latest version**, so you cannot pin an older chart | mariadb-operator-crds / mariadb-operator / mariadb-cluster 26.10.1 (also OCI on ghcr.io) |
| Commercial support | Percona support subscriptions; Percona Everest GUI | Percona support | Oracle MySQL Enterprise Edition subscription. The GA blog says the operator is "available to customers as part of MySQL Enterprise Edition" [D] | Community: none from the project. MariaDB plc sells the **MariaDB Enterprise Operator** as a separate product (see section 4.9) |

---

## 1. Percona Operator for MySQL based on Percona XtraDB Cluster 1.20.0

### 1.1 Scope and versions
- **DB versions [V]** (from RN 1.20.0 and deploy/cr.yaml):
  - PXC 8.4.8-8.1 (the default in cr.yaml), 8.0.45-36.1, 5.7.44-31.65.
  - XtraBackup 8.4.0-5.1 / 8.0.35-35.1 / 2.4.29.
  - HAProxy 2.8.18-1; ProxySQL 2.7.3-1.3 and ProxySQL 3.0.6-1.1.
  - fluent-bit 5.0.6; PMM client 2.44.1 (deprecated, to be removed in 1.22) and PMM client 3.8.0; cert-manager 1.20.2.
  - Full ARM64 support for all images arrived in 1.20.0.
- **Topology:** Galera synchronous multi-primary (normally 3+ nodes).
  - Cross-site async replication between PXC clusters uses `replicationChannels` (replication.md, dr-*.md).
  - The docs also show a multi-DC DR setup.
- **Proxies:** HAProxy (the default) or ProxySQL 2/3. The docs cover switching between them (proxy-switching.md).
- **Platforms tested** (from RN 1.20.0): GKE 1.33–1.35, EKS 1.33–1.35, AKS 1.33–1.36, OpenShift 4.18–4.21, and Minikube 1.38.1 (K8s 1.35.1). The docs claim compatibility with any CNCF-conformant distribution.

### 1.2 Backups [V/D]
- **Engine:** physical backups with XtraBackup.
  - The default "SST method" runs a backup Pod that joins the cluster as an SST donor.
  - An "XtraBackup sidecar method" is in tech preview behind the `XtrabackupSidecar` feature gate.
- **Storage targets:**
  - `s3` (and S3-compatible), `azure`, and `filesystem` (PVC). [V] Source: pkg/apis/pxc/v1/pxc_types.go defines only these 3 types.
  - There is no native GCS type; GCS works only through its S3-compatible endpoint [U].
- **Scheduling and retention:**
  - Schedules use cron under `backup.schedule`, with retention by `count` and `deleteFromStorage`.
  - The default cr.yaml **enables a daily backup to fs-pvc out of the box**. The hands-on tester should note that a PVC gets created for it.
- **PITR:**
  - A binlog collector uploads binlogs to S3 or Azure.
  - Restore targets are `date`, `transaction` (GTID), `latest` and `skip`.
  - 1.20.0 added extensive PITR validation (K8SPXC-1318/1634/1635/1793/1872/1892).
- **Restore:** to the same cluster or a new cluster (backups-restore-to-new-cluster.md). You can also move from an external DB (backups-move-from-external-db.md) and copy backups (backups-copy.md).
- **Compression:** supported (backups-compress.md).
- **Not available:**
  - Incremental backups.
  - Native backup encryption. The sidecar method's "native encryption" is listed as "not yet available in 1.19.0".
  - **compare.md itself marks incremental backups as not supported.**

### 1.3 HA, recovery and operations [D]
- **Full cluster crash** (recovery.md):
  - `pxc.autoRecovery: true` is the default.
  - A semi-automatic mode (find the highest seqno, then `kill -s USR1 1`) and a manual mode using debug images are also documented.
  - 1.20 improved the selection of the bootstrap node (K8SPXC-1828).
- **Other HA/failure material:** failover pages (failover-about.md, failover-in-cluster.md, dr-failover.md), an SST retry limit (new in 1.20), and pause/resume (pause.md).
- **Upgrades:**
  - Operator: CRD then Deployment.
  - DB: `updateStrategy: SmartUpdate`, plus automatic upgrades through Version Service (`upgradeOptions.apply`). They are disabled in the default CR.
  - Separate pages cover manual, OpenShift and pinning a specific version.
- **Scaling:** horizontal and vertical. **Storage autoscaling (new in 1.20)** uses `storageScaling.autoscaling` with a threshold, step and maxSize; manual volume expansion is also supported.
- **TLS:** on by default. The operator self-generates certificates or uses cert-manager. Migrating to cert-manager is documented. Automated certificate rotation via a `<secret>-new` Secret is new in 1.20.
- **Data at rest:** keyring plugins and HashiCorp Vault (encryption*.md).
- **Users:** declarative `spec.users` since 1.16.0 (users.md). There are no separate Database or Grant CRDs; grants live in `spec.users`.
- **Monitoring:**
  - PMM2 (deprecated) and PMM3.
  - A Kubernetes monitoring guide (monitor-kubernetes.md, kube-state-metrics).
  - No ServiceMonitor or Prometheus-exporter integration is documented; the only path is "custom exporters via sidecars".
- **Logging:** a fluent-bit log collector, custom logrotate (1.20), and persistent logging.
- **Customization:** sidecars (sidecar.md), anti-affinity and constraints (constraints.md), annotations, cluster-wide mode, custom registry, and an OLM/OpenShift install.

### 1.4 Troubleshooting
- There is a full "Troubleshooting" section: debug.md, debug-events, debug-logs, debug-shell, debug-images, debug-storage.
- Also: faq.md (10+ Q&As), get-help.md, and a crash-recovery page.
- **There is no dedicated "known limitations" page.** Limitations are scattered across pages and tech-preview notes.

### 1.5 Exact quickstart commands (as given in the docs)
The default path is Quickstart → kubectl.md. Live page: https://docs.percona.com/percona-operator-for-mysql/pxc/kubectl.html

```bash
kubectl create namespace <namespace>
kubectl apply --server-side -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/bundle.yaml -n <namespace>
kubectl apply -f https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/v1.20.0/deploy/cr.yaml -n <namespace>
kubectl get pxc -n <namespace>          # expect cluster1 ... ready, 3 PXC + 3 HAProxy
```
- **CRD step:** the CRDs are bundled in bundle.yaml (3 CRDs [V]) together with a namespaced Role, ServiceAccount and Deployment.
- **Helm** (helm.md). The page pins no chart version:

```bash
helm repo add percona https://percona.github.io/percona-helm-charts/ && helm repo update
kubectl create namespace <namespace>
helm install my-op percona/pxc-operator --namespace <namespace>
helm install my-db percona/pxc-db --namespace <namespace>
```
- **Minikube** (minikube.md): `minikube start --memory=4096 --cpus=3`, then bundle.yaml with `--server-side`, then **cr-minimal.yaml**.
- **Client pod:**
  - connect.md uses `--image=percona/percona-xtradb-cluster:8.4`, which exists [V].
  - **The platform guides (gke/eks/aks/minikube/openshift/kubernetes) use `--image=percona:8.4`, which does NOT exist on Docker Hub [V].** The official `percona` image tops out at 8.0.x / 9.7. See defect P1.

---

## 2. Percona Operator for MySQL (Percona Server) 1.2.0

### 2.1 Scope and versions
- **DB versions [V]** (RN 1.2.0, cr.yaml):
  - PS 8.4.10-10.1 (the default) and 8.0.46-37.1.
  - XtraBackup 8.4.0-6.1 / 8.0.35-36.1.
  - MySQL Router 8.4.10 / 8.0.46; HAProxy 2.8.18-1; Orchestrator 3.2.6-22; Percona Toolkit 3.7.1-4; PMM client 3.8.1 (PMM3 only); cert-manager 1.20.2; Percona Binlog Server 0.3.1.
  - There is no 5.7 support.
- **Topologies:**
  - Group Replication (GA, recommended).
  - Async replication with Orchestrator (**tech preview**).
  - Changing the replication type requires pausing the cluster.
  - Semi-sync is not supported.
  - GR is limited to 9 members (limitations.md).
- **Proxies:**
  - HAProxy (the default) or MySQL Router; the two are mutually exclusive.
  - Router works only with GR. Async requires HAProxy.
  - There is no ProxySQL.
- **Cross-site:** **InnoDB ClusterSet** via the new `PerconaServerMySQLClusterSet` CRD (new in 1.2.0, GR only). Switchover is user-initiated; there is no auto-rejoin.
- **Platforms tested:** GKE 1.33–1.35, EKS 1.33–1.36, OpenShift 4.18–4.22, and Minikube 1.38.1. **AKS is not listed**, whereas the PXC operator lists it.

### 2.2 Backups [D]
- **Engine:** XtraBackup physical backups.
- **Storage:** S3, GCS (native `gcs` type) and Azure. **No local or PVC backups** (limitations.md).
- **Scheduling:** schedules with `keep` retention. Caveat: when several schedules share a storage location, retention applies only to the first schedule.
- **Compression:** zstd only.
- **Encryption:** **encrypted backups are new in 1.2.0** (XtraBackup native AES256; the key is held in a Secret).
- **Incremental backups:** available since 1.1.0, **tech preview**.
- **PITR:** **tech preview**. Binlogs are collected by Percona Binlog Server, which supports S3 only. In 1.2.0 the binlog source can be defined in the Restore CR for cross-cluster PITR. The 1.2.0 Binlog Server image is incompatible with the earlier one.
- **Restore:** to the same or a new cluster. There is a dedicated backup/restore debug page.

### 2.3 HA and operations [D]
- **Failover:** GR elects the primary itself; async relies on Orchestrator. (features.md wrongly says Orchestrator handles failover for everything; see defect S6.)
- **Full cluster crash:** `mysql.autoRecovery` exists in the CR reference, and a `FullClusterCrashDetected` condition appears in cr-statuses.md. **There is no dedicated crash-recovery or how-to page** (PXC has one). pause.md notes that a GR cluster runs crash recovery on every unpause.
- **Upgrades:** `SmartUpdate` (update-db.md); CRD updates via Helm or manually; OpenShift.
- **Scaling and storage:** storage autoscaling (new in 1.2.0) plus an option to delegate to an external autoscaler.
- **TLS and secrets:**
  - TLS via cert-manager or the operator; rotation is documented (tls-update.md).
  - Vault data-at-rest encryption, with Secret validation added in 1.2.0.
  - A `<cluster>-psuser-root` connection Secret (1.2.0).
- **Users:** **there is no declarative user CRD/spec in 1.2.0.** The live users.md tells you to create users manually in SQL; `spec.users` appears only on the docs `main` branch as "Version added 1.3.0".
- **Monitoring and logging:** PMM3 and kube-state-metrics guidance. No ServiceMonitor is documented. There is no log collector (no fluent-bit) [U: not found in docs].
- **Other:** sidecars, anti-affinity and constraints, annotations, cluster-wide mode, telemetry, and a known-limitations page (limitations.md, which is good).

### 2.4 Troubleshooting
- Pages: debug.md (initial troubleshooting), debug-events, debug-logs, debug-shell, debug-backup-restore, cr-statuses.md (a good condition/state catalog), and limitations.md.
- **There is no FAQ.**

### 2.5 Exact quickstart commands
kubectl.md. Live page: https://docs.percona.com/percona-operator-for-mysql/ps/kubectl.html

```bash
kubectl create namespace <namespace>
kubectl apply -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/bundle.yaml -n <namespace>   # NOTE: no --server-side here (the PXC docs and the PS minikube page use it)
kubectl apply -f https://raw.githubusercontent.com/percona/percona-server-mysql-operator/v1.2.0/deploy/cr.yaml -n <namespace>
kubectl get ps -n <namespace>     # expect ps-cluster1 group-replication ... ready, 3 MySQL + 3 HAProxy
```
- **CRDs:** bundle.yaml contains **4 CRDs** [V] (backups, clustersets, restores, perconaservermysqls), but the docs' expected output lists only 3.
  - The largest CRD is about 184 KB as JSON, under the 256 KB annotation limit, so client-side apply should work [V, computed].
- **Helm** (helm.md):

```bash
helm repo add percona https://percona.github.io/percona-helm-charts/ && helm repo update
helm install my-op percona/ps-operator --namespace my-namespace --create-namespace
helm install my-db percona/ps-db --namespace my-namespace
# customised example on the same page omits --namespace (defect S3):
helm install my-db percona/ps-db --set mysql.volumeSpec.pvc.resources.requests.storage=20Gi --set backup.enabled=false
```
- **Minikube:** `minikube start --memory=4096 --cpus=3`, then `kubectl apply --server-side -f deploy/bundle.yaml`, then `kubectl apply -f deploy/cr-minimal.yaml`. These are relative paths, so the repo must be cloned first.
- **Default CR** [V]: `clusterType: group-replication`, mysql size 3, HAProxy enabled (3), Router disabled, Orchestrator disabled, an S3 backup storage placeholder, PMM disabled.

---

## 3. Oracle MySQL Operator for Kubernetes 26.7.0-2.3.0

### 3.1 Scope and versions
- **DB versions:** from 26.7 there is a single operator line compatible with MySQL Server 8.4, 9.7 and 26.7 [D, release notes].
  - Community images come from container-registry.oracle.com/mysql/community-operator, community-server and community-router.
  - The CRD has `edition: community|enterprise` [V].
- **Topology:**
  - InnoDB Cluster (Group Replication), 1–9 instances.
  - `readReplicas` (async read replicas) [V, CRD].
  - InnoDB **ClusterSet exists in code and CRD but is undocumented:** `spec.initDB.clusterSet` and the `MySQLClusterSetFailover` CRD [V source]. The official docs never mention ClusterSet.
- **Proxy:** MySQL Router only, as a Deployment.
- **Platforms:** the docs say only "Kubernetes 1.21 and newer". There is no tested-platform matrix.
- **Operator topologies:** global or namespace-scoped and standalone mode (new in 9.7.0-2.2.8, release notes). This is not covered in the user manual.

### 3.2 Backups [V CRD / D docs]
- **Engine:** logical backups with MySQL Shell `dumpInstance`.
  - A "snapshot" profile type exists in the CRD; its semantics are not documented.
  - **MEB (MySQL Enterprise Backup) physical and incremental backups, plus MEB-based PITR**, exist in source (`spec.meb`, `initDB.meb`, `MySQLBackup.spec.incremental`, mysqloperator/controller/backup/meb/*). They are **undocumented and Enterprise-only** [U].
- **Storage:** PVC, OCI Object Storage, S3 and Azure appear in the CRD reference. The backups chapter only shows PVC and OCI examples and states (as of "8.0.29") that restore from a PVC is not available.
- **Scheduling:** `backupSchedules` uses CronJob and a timeZone.
- **Missing:** retention policy, PITR (community), compression controls (beyond dumpOptions passthrough) and encryption controls.
- **Restore:** only by bootstrapping a **new** cluster through `initDB.dump`. There is no in-place restore CR. `initDB.clone` (clone plugin from a running donor) is also supported.

### 3.3 HA and operations
- **Failover:** GR built-in; Router follows the primary. The operator calls `reboot_cluster_from_complete_outage` for full outages [V source, cluster_controller.py:522]. **None of this is documented.**
- **Upgrades:** patch `spec.version` for a rolling restart, highest ordinal first. The operator upgrade re-applies the CRDs and operator from `trunk`.
- **TLS:** `tlsUseSelfSigned`, or your own Secrets (`tlsSecretName`, `tlsCASecretName`). There is no cert-manager integration doc.
- **Data at rest:** `keyring` with file, encryptedFile and OCI options [V]. There is no Vault option.
- **Users:** no user, database or grant CRDs; only the root Secret. The "MySQL Accounts Created" page lists the system accounts.
- **Monitoring and logging:**
  - `spec.metrics` runs a mysqld_exporter-style sidecar with an optional ServiceMonitor (added in 8.1.0-2.1.0).
  - `spec.logs` configures error, general and slow-query logs and a fluentd collector [V reference].
  - There is no PMM or dashboard guidance.
- **Not documented:** pause/resume, storage autoscaling, volume expansion, a scaling how-to and an anti-affinity how-to. A samples/ directory in the repo has affinity examples.

### 3.4 Troubleshooting
- There is no troubleshooting guide, FAQ or known-limitations page.
- The only related material is "7.3 Viewing Logs", which lists containers and shows sample output from **MySQL 8.0.29 in 2022**.

### 3.5 Exact quickstart commands
Ch. 2 and Ch. 3: https://dev.mysql.com/doc/mysql-operator/en/mysql-operator-installation-kubectl.html

```bash
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml   # creates ns mysql-operator, ClusterRoles
kubectl get deployment mysql-operator --namespace mysql-operator
kubectl create secret generic mypwds --from-literal=rootUser=root --from-literal=rootHost=% --from-literal=rootPassword="sakila"
kubectl apply -f mycluster.yaml   # InnoDBCluster: secretName mypwds, tlsUseSelfSigned: true, instances: 3, router.instances: 1
kubectl get innodbcluster --watch
kubectl run --rm -it myshell --image=container-registry.oracle.com/mysql/community-operator -- mysqlsh root@mycluster --sql
```
- The commands point at the **`trunk`** branch (unpinned). trunk is currently 26.7.0-2.3.0 [V].
- The CRD file has **5 CRDs** [V] (innodbclusters, mysqlbackups, mysqlclustersetfailovers, clusterkopfpeerings, kopfpeerings); the docs' expected output shows 4.
- **Helm:**

```bash
helm repo add mysql-operator https://mysql.github.io/mysql-operator/ && helm repo update
helm install my-mysql-operator mysql-operator/mysql-operator --namespace mysql-operator --create-namespace
helm install mycluster mysql-operator/mysql-innodbcluster --set tls.useSelfSigned=true --values credentials.yaml   # default namespace
```

---

## 4. mariadb-operator (community) 26.10.1

### 4.1 Scope and versions
- **DB versions:** MariaDB Community ≥ 10.6; the default image is `mariadb:12.3.3` (12.3 LTS, the new default in 26.10). MaxScale ≥ 23.08 (default `mariadb/maxscale:23.08.13-2`, **BSL**). Only official MariaDB images are supported.
- **API:** `k8s.mariadb.com/v1alpha1`, still alpha after many years.
- **Topologies:**
  - Standalone.
  - Async replication (semi-sync on by default).
  - Galera.
  - **Multi-cluster** (26.6+): cross-K8s-cluster replication over either replication or Galera clusters, also used for blue/green upgrades.
- **Proxy:** MaxScale through a `MaxScale` CRD (failover and switchover, R/W split, GUI). There is no HAProxy or ProxySQL.
- **Platforms:** Kubernetes ≥ 1.31, OpenShift ≥ 4.18 (README). There is no tested matrix. The OpenShift/OLM install comes from a separate helm-operator repo.

### 4.2 Backups [D]
- **Logical** (`Backup` CRD, mariadb-dump): S3, PVC or any volume (e.g. NFS). Supports schedule, retention (`maxRetention`), compression (gzip/bzip2) and specific databases.
- **Physical** (`PhysicalBackup` CRD, mariadb-backup or **Kubernetes VolumeSnapshots**):
  - Storage: S3, Azure Blob (26.3+), PVC and volumes.
  - Options: schedule, on-demand, retention, target pod policy, compression (gzip/bzip2/**zstd** 26.10), staging area, timeout.
- **Encryption:** **SSE-C** for S3 (server-side, customer key). There is no client-side backup encryption [U].
- **Restore:**
  - The `Restore` CRD, or `bootstrapFrom` into a new cluster from a logical or physical backup, S3, Azure, PVC or VolumeSnapshot.
  - "Target recovery time" picks the closest backup.
- **PITR** (26.3+): a `PointInTimeRecovery` CRD archives binlogs to S3 or Azure, plus a binlog inventory and strict mode. **It works only with the async replication topology, not Galera or standalone (pitr.md), and needs MariaDB ≥ 10.8.**
- **No incremental backups and no GCS type** (GCS only via S3-compatible [U]).

### 4.3 HA and operations [D]
- **Galera:** automatic cluster recovery (enabled by default, with tunable timeouts), a recovery Job, and forced bootstrap.
- **Replication:** primary failover and switchover, replica recovery from a PhysicalBackup or VolumeSnapshot, scale-out, and lag-aware probes.
- **Updates:** `ReplicasFirstPrimaryLast`, `OnDelete`, `Never`; automatic data-plane updates; restarts on my.cnf changes.
- **Operations:**
  - `suspend` (pause reconciliation).
  - **Maintenance mode** (cordon, drain, read-only).
  - Volume resize (`resizeInUseVolumes`). There is **no storage autoscaling**.
- **TLS and security:** native cert-manager integration with CA and cert rotation; root password rotation.
- **SQL resources:** declarative **User / Grant / Database / Connection / SqlJob CRDs**, also usable against `ExternalMariaDB`.
- **Monitoring:** mysqld-exporter and maxscale-exporter with **automatic ServiceMonitor** creation, plus Grafana dashboard links. There is no PMM.
- **Data at rest:** no TDE, Vault or keyring integration is documented [U].
- **Other:** sidecars and init containers (example manifest), anti-affinity, PDBs, dedicated nodes (high_availability.md).

### 4.4 Troubleshooting
- Each major page ends with a "Troubleshooting / Common errors" section: galera.md, replication.md, pitr.md, maxscale.md.
- There is **no central troubleshooting page, no FAQ and no limitations page** (pitr.md has a 2-line limitations section).
- The docs exist only as GitHub markdown, so there is **no docs website or search** beyond GitHub's own. https://mariadb-operator.github.io/mariadb-operator/ returns 404 at its root and hosts only the Helm index and assets.

### 4.5 Exact quickstart commands
docs/quickstart.md. **The quickstart never installs the operator.** It assumes you have cloned the repo and already installed the operator via helm.md.

```bash
# from helm.md (operator):
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install mariadb-operator-crds mariadb-operator/mariadb-operator-crds
helm install mariadb-operator mariadb-operator/mariadb-operator
# or OCI (README): helm install mariadb-operator-crds oci://ghcr.io/mariadb-operator/charts/mariadb-operator-crds [--version <version>] ; same for mariadb-operator, mariadb-cluster
# quickstart.md (relative paths -> requires git clone of the repo):
kubectl apply -f examples/manifests/config
kubectl apply -f examples/manifests/mariadb.yaml          # single-instance MariaDB, Service type LoadBalancer with metallb IP 172.18.0.20
kubectl apply -f examples/manifests/database.yaml -f examples/manifests/user.yaml -f examples/manifests/grant.yaml
kubectl apply -f examples/manifests/sqljobs
kubectl apply -f examples/manifests/backup.yaml           # LOGICAL backup to a 100Mi PVC, gzip
kubectl apply -f examples/manifests/mariadb_from_backup.yaml
```
- The CRDs come as a separate chart, which must be installed first. No version is pinned anywhere in the quickstart.
- Galera and replication quickstarts are inside galera.md and replication.md.

### 4.9 MariaDB Enterprise Operator (MariaDB plc) [D/U]
- **What it is:** a separate commercial product, linked from the README ("commercially supported Kubernetes operator from MariaDB with additional enterprise-grade features").
- **API and images:** a different API group, `enterprise.mariadb.com/v1alpha1`. Images come from `docker.mariadb.com` (MariaDB Enterprise Server, e.g. `enterprise-server:11.4.x`, and Enterprise MaxScale).
- **Certification and support:** Red Hat certified, and says it supports the latest 3 K8s versions (datasheet).
- **Migration:** a documented community-to-enterprise migration recreates MaxScale resources (https://mariadb.com/docs/tools/mariadb-enterprise-operator/migrations/migrate-community-operator-to-enterprise-operator).
- **Relationship to community:** it shares the same codebase lineage and feature model (Galera, MaxScale, mariadb-backup, VolumeSnapshots, TLS rotation). The commercial difference is mainly the Enterprise Server/MaxScale images, support and certification.
- **Not established:** a detailed feature delta was not verified (mariadb.com pages return 403 to scripted fetches).

---

## 5. Combined feature matrix (per docs; GA unless noted)

| Feature | PXC 1.20.0 | PS 1.2.0 | Oracle 26.7.0-2.3.0 | mariadb-operator 26.10.1 |
|---|---|---|---|---|
| DB flavours/versions | PXC 8.4 / 8.0 / 5.7 | Percona Server 8.4 / 8.0 | MySQL CE/EE 8.4 / 9.7 / 26.7 | MariaDB CE ≥ 10.6 (default 12.3.3) |
| Sync multi-primary | Galera | — | — | Galera |
| Group Replication | — | GA | GA (InnoDB Cluster) | — |
| Async replication | cross-site only | Tech preview (Orchestrator) | read replicas only | GA (semi-sync default) |
| Standalone single node | via unsafe flags / cr-minimal | via unsafeFlags | instances: 1 | yes (first-class) |
| Proxies | HAProxy, ProxySQL 2/3 | HAProxy, MySQL Router | MySQL Router | MaxScale (BSL) |
| Cross-cluster / DR | async replication channels between PXC clusters | InnoDB ClusterSet CRD (new) | ClusterSet in code, **undocumented** | Multi-cluster topology (26.6+) |
| Tested K8s matrix | GKE/EKS/AKS/OpenShift/Minikube with versions | GKE/EKS/OpenShift/Minikube (no AKS) | "K8s ≥ 1.21" only | K8s ≥ 1.31, OCP ≥ 4.18 (no matrix) |
| Physical backup | XtraBackup | XtraBackup | MEB (Enterprise, **undocumented**) | mariadb-backup + VolumeSnapshots |
| Logical backup | — | — | mysqlsh dumpInstance | mariadb-dump |
| Backup targets | S3, Azure, PVC | S3, GCS, Azure (no PVC) | PVC, OCI, S3, Azure (only PVC/OCI documented) | S3, Azure, PVC/volumes, VolumeSnapshot |
| Scheduled + retention | yes (count) | yes (keep) | schedule yes; no retention | yes (maxRetention) |
| PITR | GA (S3/Azure) | Tech preview (S3 only) | — (MEB PITR in code, undocumented) | GA, async-replication topology only |
| Incremental backups | — | Tech preview | MEB only (undocumented) | — |
| Backup encryption | — | yes (XtraBackup AES, new) | — | S3 SSE-C |
| Backup compression | yes | zstd | dumpOptions passthrough | gzip/bzip2/zstd |
| Restore into new cluster | yes | yes | only via initDB (new cluster only) | yes (bootstrapFrom) |
| Full-crash auto-recovery | yes, documented page | option + status only | in code, undocumented | Galera recovery documented |
| Smart / automatic DB upgrade | SmartUpdate + Version Service auto-upgrade | SmartUpdate | rolling on spec.version | ReplicasFirstPrimaryLast, auto data-plane |
| TLS / cert-manager | yes / yes | yes / yes | self-signed or own secrets / not documented | yes / native |
| Data-at-rest encryption | keyring + Vault | Vault | keyring file/encryptedFile/OCI | not documented |
| Declarative users | spec.users (1.16+) | **no (1.3.0 planned)** | no | User/Grant/Database CRDs |
| Monitoring | PMM2 (deprecated) / PMM3 | PMM3 | mysqld exporter sidecar + ServiceMonitor | exporters + auto ServiceMonitor |
| Log collection | fluent-bit + logrotate | not documented | fluentd collector | not documented |
| Storage autoscaling | yes (1.20) | yes (1.2) + external | — | — (manual resize only) |
| Pause / suspend | pause | pause | — | suspend + maintenance mode |
| Custom sidecars | yes | yes | podSpec | yes |
| ARM64 | yes (1.20) | yes | [U] | yes |
| GUI | Percona Everest | — | — | MaxScale GUI |
| Troubleshooting docs | Section + FAQ | Section + limitations page | Logs page only | per-topic sections |

---

## 6. Documentation defects (concrete, with URLs)

### Percona PXC docs (https://docs.percona.com/percona-operator-for-mysql/pxc/)
- **P1 (high).** The platform install guides tell users to run `kubectl run ... --image=percona:8.4`. **Tag `percona:8.4` does not exist on Docker Hub** [V; official tags stop at 8.0.46 / 9.7.2], so the command will fail with ImagePullBackOff.
  - Affected: gke.html, eks.html, aks.html, minikube.html, openshift.html, kubernetes.html (fragment assets/fragments/connectivity.txt).
  - Example: https://docs.percona.com/percona-operator-for-mysql/pxc/gke.html
- **P2 (high).** compare.html ("Compare various solutions") is badly outdated and is competitive collateral. https://docs.percona.com/percona-operator-for-mysql/pxc/compare.html
  - It says the PXC operator supports MySQL "5.7, 8.0" (8.4 is the default) and the PS operator "8.0" (8.4 is default, and PS has PITR as tech preview).
  - It says Oracle's operator is "Apache 2.0" (it is UPL 1.0) and "8.0" only.
  - It omits MariaDB operator entirely, and the PXC link is `https:///` (broken).
- **P3 (medium).** The supported-versions pages contradict each other.
  - System-Requirements.html says PXC 8.4.8-8.1 is "(Tech preview)".
  - versions.html shows 8.4 without the tech-preview label since 1.19.0.
  - RN 1.20.0 calls 8.4 the "default and recommended version".
- **P4 (medium).** backups.html is stale and inaccurate. https://docs.percona.com/percona-operator-for-mysql/pxc/backups.html
  - It says native encryption and incremental backups are "not yet available in version 1.19.0" (the current release is 1.20.0).
  - It says the sidecar uploads to "S3, Azure, or GCP" and "Only cloud storage backups (S3, Azure, GCP)", but there is no GCS storage type (operator.md: "Only s3, azure, and filesystem"; source: pxc_types.go).
- **P5 (medium).** The kubectl.html "Expected output" for bundle.yaml lists 4 CRDs, including a non-existent `perconaxtradbbackups.pxc.percona.com`; the bundle has 3 [V].
  - With `--server-side`, kubectl prints "serverside-applied", not "created".
  - The CR output has a stray space: `perconaxtradbcluster.pxc.percona.com/ cluster1`.
- **P6 (medium).** The quickstart overview says "Set up and make a **logical** backup", and backup-tutorial.md says "make a logical backup". The operator only does physical XtraBackup backups.
- **P7 (low/medium).** The kubectl.html quickstart offers Minikube as a prerequisite but deploys the full cr.yaml. That CR requires 3 nodes because of hostname anti-affinity on PXC and HAProxy. There is no pointer to cr-minimal.yaml on that page.
- **P8 (low).** Broken links [V, 404]:
  - Wrong tag format (missing `v` prefix):
    - `https://raw.githubusercontent.com/percona/percona-xtradb-cluster-operator/1.20.0/deploy/cr.yaml` (data-source.md).
    - `https://github.com/percona/percona-xtradb-cluster-operator/blob/1.20.0/deploy/backup/restore.yaml` (backups-move-from-external-db.md).
  - `https://github.com/percona/percona-operator/issues` and `/pulls` (index.md).
  - Other Percona docs that no longer resolve:
    - `https://docs.percona.com/everest/quickstart-guide/quick-install.html` (what-next.md)
    - `https://docs.percona.com/percona-server/latest/rotating-master-key.html` (encryption.md)
    - `https://docs.percona.com/percona-xtradb-cluster/8.0/install/index.html` (backups-move-from-external-db.md)
    - `https://docs.percona.com/percona-xtrabackup/innovation-release/{xtrabackup-option-reference,xbstream-options,xbcloud-options}.html` (operator.md)
    - `https://docs.percona.com/percona-server/innovation-release/proxy-protocol-support.html` (haproxy-conf.md)
    - `https://proxysql.com/compare` (architecture.md)
    - `https://github.com/kubernetes/kube-state-metrics/blob/main/docs/customresourcestate-metrics.md`
  - Totals: 515 unique external links checked, 30 non-200. Most of the rest are dev.mysql.com 403 bot-blocks, which are not real failures.
- **P9 (low).** The nav links "Building and testing the Operator" and "Contributing" are pinned to `v1.18.0` (mkdocs-base.yml).
- **P10 (low).** The helm.html quickstart pins no `--version`. The Helm repo already has pxc-operator chart 1.20.1 (appVersion 1.20.0), so the installed chart drifts from the docs.
- **P11 (low).** The versions.html 1.20.0 row omits ProxySQL 3.0.6 (it is listed in the RN and the images table). XtraBackup 8.4.0-5.1 is paired with PXC 8.4.8.
- **P12 (low).** kubectl.html contains typos and confusion: "Install not already installed"; the intro text says the operator is for "Percona Server for MySQL" (it is for PXC).

### Percona PS docs (https://docs.percona.com/percona-operator-for-mysql/ps/)
- **S1 (high).** users.html uses `--image=percona:8.4` twice, and that tag does not exist [V]. It also hard-codes `-proot_password`, while the root password is generated into a Secret.
  - Users are told to create accounts manually; declarative users are not available until 1.3.0.
  - Page: https://docs.percona.com/percona-operator-for-mysql/ps/users.html
- **S2 (medium).** The kubectl.html expected output lists 3 CRDs, but the v1.2.0 bundle has 4 (`perconaservermysqlclustersets` is missing) [V]. The step also omits `--server-side`, unlike minikube.html and the PXC docs (inconsistent).
- **S3 (medium).** In helm.html, the customised `helm install my-db percona/ps-db --set ...` example omits `--namespace`, so it installs into `default` despite "deploy ... in the my-namespace namespace".
- **S4 (medium).** The quickstart overview promises a "**logical** backup" (backups are physical XtraBackup).
- **S5 (medium).** There is no crash-recovery or full-cluster-outage page for GR. Only `mysql.autoRecovery` in the reference and status conditions exist. PXC has a full page.
- **S6 (low/medium).** features.html says "Automatic failover with intelligent primary election handled by the Orchestrator". For GR (the GA, default topology) failover is GR-native; Orchestrator is only used for async, which is tech preview.
- **S7 (low).** AKS is missing from the tested platforms even though variables.yml defines `aksrecommended: '1.35'`. The version pairing differs from PXC (EKS up to 1.36 here versus 1.35 for PXC).
- **S8 (low).** Broken links [V]:
  - `https://docs.percona.com/legacy-documentation` (404 without the trailing slash; images.md, update-*.md, RNs).
  - The XtraBackup `innovation-release` option-reference links (backup-cr.md, restore-cr.md, operator.md).
  - The kube-state-metrics link.
  - Totals: 211 links checked, 25 non-200, mostly dev.mysql.com 403 bot-blocks.
- **S9 (low).** Release-date inconsistency: variables.yml says v0.10.0 is 2025-06-04, while the GitHub release is 2025-06-06.
- **S10 (info).** The `main` branch of k8sps-docs already contains unreleased 1.3.0 content (users CRD, TLS leaf rotation). It is not published yet, but there is a risk of a premature publish.

### Oracle MySQL Operator docs (https://dev.mysql.com/doc/mysql-operator/en/)
- **O1 (high).** Major features are absent from the docs:
  - InnoDB ClusterSet: the `MySQLClusterSetFailover` CRD and `initDB.clusterSet`.
  - MEB physical, incremental and PITR backups (`spec.meb`, `initDB.meb`, `MySQLBackup.spec.incremental`).
  - The operator topologies / standalone mode (9.7.0-2.2.8).
  - Full-outage reboot behaviour.
  - Properties chapter 8 has no `meb`, `clusterSet`, `incremental` or `instanceService` entries [V].
- **O2 (high).** There are no HA/failover, scaling, TLS/cert-manager, monitoring how-to, troubleshooting, FAQ or limitations chapters. The "Viewing Logs" page shows MySQL **8.0.29** logs from **2022-04-21**.
- **O3 (medium).** Stale version references:
  - "functions with Kubernetes 1.21 and newer" (installation.html).
  - Storage and restore limitations stated "as of MySQL Operator for Kubernetes 8.0.29" (backups.html).
  - The upgrade example uses `community-operator:8.4.0-2.1.3` and MySQL 8.4.0.
  - Manifest examples use `version: 9.6.0` (innodbcluster-common.html, simple-helm.html), while the current release is 26.7.0.
  - The private-registry page gives `9.6.0-2.2.6` as an example version, but that combination never existed (9.6.0 shipped with 2.2.7).
- **O4 (medium).** The install-by-manifest expected output lists 4 CRDs; trunk deploy-crds.yaml has 5 [V]. The install commands use `trunk` instead of a release tag, so they are not reproducible.
- **O5 (medium).** The backups chapter documents only PVC and OCI. S3 and Azure are in the reference only, with no examples or restore walkthrough. It still says a PVC "restore capability is not available". It has no retention or PITR guidance. It contains the typo "PrivateVolumeClaim" and "iniDB".
- **O6 (low).** simple-helm.html says the examples use the public artifacthub.io repository, but they actually use `https://mysql.github.io/mysql-operator/`. The Helm repo index keeps only the latest chart (2.3.0), so older versions cannot be installed from it.
- **O7 (low).** The README says it "deploys the latest MySQL Operator from DockerHub", but the manifests use container-registry.oracle.com. In the docs footer, the `pls/topic/lookup?ctx=acc&id=info|trs` links return 404.
- **O8 (info).** The release notes are thin. 26.7.0-2.3.0 has one bug-fix bullet plus the versioning change. Release-note dates differ from git tag commit dates (e.g. 26.7.0 tag commit 2026-07-21 versus notes 2026-07-31).

### mariadb-operator docs (GitHub /docs)
- **M1 (medium).** quickstart.md has no operator or CRD install step and no link to helm.md. It uses relative paths (`examples/manifests/...`) that require a git clone of `main`, not of a release tag.
- **M2 (medium).** The quickstart `mariadb.yaml` uses `service.type: LoadBalancer` with a MetalLB annotation `metallb.io/loadBalancerIPs: 172.18.0.20` (kind-specific). The expected output shows `ClusterIP`, so it is inconsistent and will stay Pending on clusters without an LB.
- **M3 (medium).** There is no versioned docs site, no search and no central troubleshooting, FAQ or limitations page. The docs on `main` can describe unreleased features; nothing marks which release a feature arrived in, apart from release notes. https://mariadb-operator.github.io/mariadb-operator/ returns 404.
- **M4 (low).** The PITR limitation (async replication only; no Galera or standalone) appears only inside pitr.md. The README feature list advertises PITR without that caveat.
- **M5 (low).** helm.md mixes OCI (`--version <version>`) and classic repo installs with no version pinned. The README OCI commands also have no `--version`.
- **M6 (low).** Broken link `https://prometheus-operator.dev/docs/operator/api/` (404, metrics.md). Totals: 139 links checked, 9 non-200 (the rest are mariadb.com 403 bot-blocks).
- **M7 (info).** The API is still `v1alpha1`, and the generated API reference (api_reference.md, 3.6k lines) is complete for the 12 CRDs. Typos: "accordinly", "utilizied", "MariaB", "specifield".

---

## 7. Scores (1–10, documentation only)

| Category | PXC 1.20.0 | PS 1.2.0 | Oracle 2.3.0 | mariadb-operator 26.10.1 |
|---|---|---|---|---|
| Getting started | 7 | 7 | 6 | 5 |
| Backup / restore | 8 | 8 | 3 | 8 |
| HA / failure | 8 | 6 | 2 | 8 |
| Day-2 ops | 8 | 7 | 3 | 8 |
| Troubleshooting | 8 | 7 | 2 | 6 |
| Reference (CR/API) | 8 | 8 | 5 | 8 |
| Accuracy / freshness | 6 | 6 | 3 | 7 |
| **Average** | **7.6** | **7.0** | **3.4** | **7.1** |

Rationale per docs set:
- **PXC:** this is the most complete and best-structured set. It has a dedicated crash-recovery page, failover and DR, a troubleshooting section plus FAQ, PITR and a 3.3k-line CR reference. It loses points for the stale compare page, the broken `percona:8.4` client image in every platform guide, 8.4 tech-preview contradictions and dead cross-product links.
- **PS:** this set has good structure, an excellent limitations page and a cr-statuses page. Weaknesses:
  - There is no GR crash-recovery how-to.
  - Many headline features are still tech preview (async, PITR, incremental).
  - Quickstart output drift: the expected output misses the ClusterSet CRD, the Helm example omits the namespace, and users.md uses the non-existent image.
- **Oracle:** this is a thin manual (about 25 pages) that has not kept pace with the product. Features that exist in the CRD (ClusterSet, MEB, incremental) are undocumented, and examples date from 2022 (8.0.29). It has no troubleshooting or HA content. The auto-generated property reference is its strongest part, but it is incomplete.
- **MariaDB:** this set is feature-rich and technically deep, with per-topic troubleshooting, a complete generated API reference and a large examples catalog (80+ manifests). Weaknesses: GitHub-only delivery (no site, search or versioning), a quickstart that skips the operator install and assumes a repo clone, and no central troubleshooting or limitations page.

## 8. Notes for the hands-on tester
- **PXC:**
  - Expect `kubectl apply --server-side` (bundle, 3 CRDs).
  - The default CR enables a daily PVC backup.
  - Default cr.yaml needs 3 schedulable nodes (anti-affinity); use cr-minimal.yaml on single-node clusters.
  - Client image: use `percona/percona-xtradb-cluster:8.4`, not `percona:8.4`.
- **PS:**
  - The docs apply bundle.yaml without `--server-side`; this should still work (CRD under 256 KB as JSON).
  - Expect 4 CRDs.
  - The default CR is GR + 3 HAProxy and has no PVC backup option.
  - Use `percona/percona-server:8.4` as the client image.
- **Oracle:**
  - The `trunk` URLs currently resolve to 26.7.0-2.3.0.
  - The operator always goes into the `mysql-operator` namespace with ClusterRoles.
  - InnoDBCluster needs a pre-created root Secret, and `tlsUseSelfSigned: true` in the examples.
  - The Helm `mysql-innodbcluster` chart defaults to MySQL 26.7.0 (appVersion).
- **MariaDB:**
  - Install the CRDs chart first, then the operator chart.
  - The quickstart requires cloning the repo, and `examples/manifests/config` must be applied first (it creates Secrets and a ConfigMap, including MinIO and SSE-C keys).
  - The quickstart MariaDB is standalone with a LoadBalancer Service.
  - Galera and replication examples are `examples/manifests/mariadb_galera.yaml` and `mariadb_replication.yaml`.

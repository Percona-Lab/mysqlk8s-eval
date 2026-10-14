# MariaDB operator: licensing and non-OSS dependencies

Research date: 2026-10-14. Subject: community `mariadb-operator` 26.10.1 (MIT, "Copyright © 2023 MariaDB plc", `LICENSE` line 3), plus MariaDB plc's separate **MariaDB Enterprise Kubernetes Operator**.
Repo paths below are relative to the shallow clone at commit `e071201b` (2026-10-07), i.e. `scratchpad/docs/mariadb-operator/`.
**Not legal advice.** This is an engineering reading of licence texts and code. Anyone making a compliance decision should get counsel to review the actual licence files.

## TL;DR

- **Every core feature of the community operator works without MaxScale**, using only GPL (MariaDB Server, Galera, mariadb-backup), MIT (operator, including its agent sidecar), and Apache-2.0 (mysqld-exporter) components. That covers Galera and async replication HA, operator-driven auto-failover and switchover, `-primary`/`-secondary` Services, physical, logical and VolumeSnapshot backups, PITR, multi-cluster, Connections, TLS, SQL CRDs and maintenance mode.
- **MaxScale is optional.** It adds read/write split in one endpoint, transaction replay, connection pooling, MaxScale-driven failover and switchover, cooperative monitoring, MaxScale filters and the MaxScale GUI. The community docs recommend MaxScale for production HA (`docs/high_availability.md:9`, `docs/replication.md:218,264`). MaxScale licensing is version dependent:
  - **23.08.x (the operator's default image since 26.10.0, `mariadb/maxscale:23.08.13-2`)**: BSL 1.1 with a Change Date of **2026-09-21**. That date has passed, so by the licence's own terms the 23.08 series is now **GPLv2+**.
  - **23.08.0–23.08.5 (the default image in operator 0.38.x through 26.6.x was `23.08.5`)**: the LICENSE file shipped in those tags carries per-version Change Dates (23.08.5 = **2028-02-27**). MariaDB's README table lists 23.08 = 2026-09-21. Read conservatively, those older images are still BSL.
  - **24.02.x** (Docker Hub `latest` = 24.02.9-2): BSL until **2027-04-10**.
  - **25.01 and later (25.01, 25.10)**: **proprietary and closed source**. They need a paid MariaDB subscription and are distributed only through `docker.mariadb.com`, or as a `-trial` image on Docker Hub that needs a licence key.
- **Galera with MaxScale under BSL.** The BSL Additional Use Grant allows production use only with "a total of less than three server instances". A 3-node Galera cluster behind MaxScale has 3 servers, so it falls outside the grant. Production use of any BSL-period MaxScale (24.02.x, 23.08.0–5) in that topology would need a commercial licence from MariaDB plc.
- **MariaDB Enterprise Operator** is a separate, subscription-gated product. Its images (operator, Enterprise Server, MaxScale 25.x, nslcd) are in the private registry `docker.mariadb.com`, which requires a Customer Download Token. Its extras include Enterprise Server, FIPS 140-3 mode, PAM/LDAP and HashiCorp Vault key-management plugins, Red Hat-certified UBI images and ppc64le.

## 1. Feature-by-feature

| Feature | Needs MaxScale? | Works without MaxScale (how) | Licence of required components | Source |
|---|---|---|---|---|
| Galera cluster provisioning, bootstrap, full-cluster crash recovery | No | Operator monitors Galera health and runs the recovery Jobs itself (it finds the highest seqno and bootstraps from it). | MariaDB Server + Galera: GPLv2. Operator and its agent sidecar: MIT. | `docs/galera.md:5-7,88-120` |
| Galera primary routing (`<name>-primary` Service) | No | The operator creates `<name>-primary` with a selector on `statefulset.kubernetes.io/pod-name` set to `status.currentPrimaryPodIndex`. It creates `<name>-secondary` over all the other pods, with Endpoints the operator manages itself. | MIT / GPLv2 | `internal/controller/mariadb_controller.go:503-517,741-779,781-816`; `docs/high_availability.md:31-39` |
| Galera auto-failover of the "primary" (write) pod | No | `PodGaleraController`: when the current primary pod goes NotReady, the operator patches `spec.galera.primary.podIndex` to a healthy pod, and the Service selector follows. `autoFailover` defaults to `true`. This path is **disabled when `maxScaleRef` is set**. | MIT / GPLv2 | `internal/controller/pod_galera_controller.go:78-124` (line 117 `|| mariadb.IsMaxScaleEnabled()`); `api/v1alpha1/mariadb_galera_types.go:63-76` |
| Galera manual switchover | No | Change `spec.galera.primary.podIndex`. Skipped if MaxScale is enabled. | MIT / GPLv2 | `pkg/controller/galera/controller.go:93-95`; `docs/high_availability.md:39` |
| Async replication setup (GTID, semi-sync) | No | Operator configures replication users, semi-sync and monitoring. | GPLv2 / MIT | `docs/replication.md:41-107` |
| Async replication switchover | No (MaxScale optional) | The operator runs FTWRL → `read_only` → wait for replica sync → promote → repoint. With MaxScale, the operator instead calls the MaxScale switchover API. | GPLv2 / MIT (or BSL/proprietary MaxScale if used) | `docs/replication.md:215-257`; `pkg/controller/replication/switchover.go:33-35`; `internal/controller/mariadb_controller_update.go:345-355` |
| Async replication auto-failover | No (MaxScale optional) | `PodReplicationController` promotes the most up-to-date ready replica. `autoFailover` defaults to true, with an optional `autoFailoverDelay`. Disabled when MaxScale is enabled, because MaxScale's `mariadbmon` then owns failover. | GPLv2 / MIT | `internal/controller/pod_replication_controller.go:63-149`; `api/v1alpha1/mariadb_replication_types.go:90-99`; `docs/replication.md:261-312` |
| Rolling updates ("replicas first, primary last") | No | The operator does a switchover before updating the primary. If MaxScale is referenced, it triggers the MaxScale switchover instead. | MIT | `docs/replication.md:318-323`; `internal/controller/mariadb_controller_update.go:194-200,345-355` |
| Read/write split in a single endpoint (readwritesplit) | **Yes** | Partial substitute: apps use two endpoints (`-primary` for writes, `-secondary` for reads). There is no query-level routing. | MaxScale (BSL 23.08/24.02, or proprietary 25.x) | `docs/maxscale.md:9-14,56-62`; `docs/high_availability.md:43-49` |
| Connection routing during failover (client sees a single stable endpoint) | Partial | Without MaxScale, the K8s Service selector is repointed. Existing connections break and clients must reconnect. Lagged replicas are dropped from `-secondary` via the readiness probe. | MIT | `docs/high_availability.md:37`; `docs/replication.md:192-196` |
| Transaction replay | **Yes** | No equivalent in the operator (MaxScale `transaction_replay`). | MaxScale | `docs/maxscale.md:13,136-140`; `docs/high_availability.md:47` |
| Connection pooling | **Yes** | None in the operator. An external OSS pooler (ProxySQL, GPLv3) could be self-managed, but is not integrated. | MaxScale | `docs/high_availability.md:49` |
| Old primary auto-rejoin as replica (MaxScale semantics) | Yes (as described) | The operator's own failover reconnects replicas, and the replica-recovery controller exists. The MaxScale-specific "auto_rejoin" toggle is not available. | MaxScale | `docs/high_availability.md:48`; `internal/controller/mariadb_controller_replica_recovery.go` |
| MaxScale HA (2+ MaxScale pods, cooperative monitoring) | Yes (MaxScale-only concept) | N/A | MaxScale | `docs/maxscale.md:514-533`, `:209` |
| MaxScale GUI | Yes | N/A | MaxScale | `docs/maxscale.md:582-606` |
| MaxScale filters (26.10.1 new) | Yes | N/A | MaxScale | `docs/maxscale.md:333-357`; `docs/releases/RELEASE_26.10.1_HEADER.md.gotmpl:25` |
| MaxScale metrics | Yes | `mysqld-exporter` for MariaDB metrics needs no MaxScale. | prom/mysqld-exporter Apache-2.0; `mariadb/maxscale-prometheus-exporter-ubi` (licence not stated on Docker Hub, unverified) | `deploy/charts/mariadb-operator/values.yaml:336-343`; `README.md:47` |
| Physical backups (mariadb-backup or VolumeSnapshot), S3/Azure/PVC | No | Jobs run `mariadb-backup` from the MariaDB image, or use the CSI VolumeSnapshot API. | mariadb-backup GPLv2; CSI driver (vendor) | `docs/physical_backup.md:38-63` |
| Logical backups (mariadb-dump) | No | Jobs | GPLv2 | `docs/logical_backup.md` |
| PITR (binlog archival + replay) | No | No MaxScale reference in `docs/pitr.md`. | GPLv2 / MIT | `docs/pitr.md`; `internal/controller/mariadb_controller_pitr.go` |
| Multi-cluster replication (DR across K8s clusters) | No (MaxScale optional) | The replica cluster's primary replicates from the remote `-primary` Service / LB. MaxScale variants are documented as optional. | GPLv2 / MIT | `docs/multi-cluster.md:66,438-481,522-560,763-766` |
| `Connection` CRD (generated DSN Secrets, health checks) | No | `mariaDbRef` points at `<name>-primary` for HA. `maxScaleRef` is optional. | MIT | `docs/connections.md:48,257-279`; `internal/controller/mariadb_controller.go:1089-1098` |
| Maintenance mode (cordon/drain/read-only) | No | Operator-native. With MaxScale only cordon is supported, set on the MaxScale CR. | MIT | `docs/maintenance.md:21-28,222-226` |
| TLS, cert-manager, SQL CRDs (User/Grant/Database), ExternalMariaDB, suspend | No | Operator-native | MIT | `docs/tls.md`, `docs/sql_resources.md`, `docs/external_mariadb.md` |

Code-level summary: `IsMaxScaleEnabled()` (`api/v1alpha1/mariadb_types.go:1063-1065`, which just checks `spec.maxScaleRef != nil`) is used only to (a) turn off the operator's own failover and switchover so MaxScale owns them (`pod_galera_controller.go:117`, `pod_replication_controller.go:142`, `pkg/controller/galera/controller.go:94`, `pkg/controller/replication/switchover.go:34`, `api/v1alpha1/mariadb_replication_types.go:489`), (b) read the primary from MaxScale status (`internal/controller/mariadb_controller_status.go:267-284,387-393`), and (c) avoid conflicts during MaxScale operations (`mariadb_controller_update.go:194`, `mariadb_controller_multicluster.go:341`, `pkg/controller/replication/controller.go:184`, `pkg/controller/maintenance/read_only.go:93`). No feature is gated on a licence check, and the code contains no licence-key handling.

## 2. MaxScale image defaults and licence status

### Default MaxScale image by community-operator version

| Operator | Default MaxScale image | Source |
|---|---|---|
| 0.38.1, 25.08.0, 25.10.0, 25.10.4 | `docker-registry2.mariadb.com/mariadb/maxscale:23.08.5` | raw `deploy/charts/mariadb-operator/values.yaml` at each tag (GitHub) |
| 26.3.0 | `docker-registry2.mariadb.com/mariadb/maxscale` tag `23.08.5` | same; also `docs/releases/RELEASE_26.3.0_HEADER.md.gotmpl:203` |
| 26.6.0 | `mariadb/maxscale:23.08.5` | values.yaml @26.6.0 |
| 26.10.0, 26.10.1 | `mariadb/maxscale:23.08.13-2` | `deploy/charts/mariadb-operator/values.yaml:332-335`; `docs/docker.md:22-26`; `docs/releases/RELEASE_26.10.0_HEADER.md.gotmpl:78` (PR #1911) |

Notes:
- The repo's `config/manager/manager.yaml:47-60` is stale: it pins MariaDB 11.4.5 and operator 0.34.0 but already shows `RELATED_IMAGE_MAXSCALE=mariadb/maxscale:23.08.13-2`. The Helm chart is authoritative.
- README "MaxScale compatibility: MaxScale >= 23.08" (`README.md:97-98`). Users can set any image; the operator has no licence-key plumbing for 25.x (not tested).
- Default MariaDB image: `mariadb:12.3.3` (Docker official, GPLv2) (`values.yaml:327-329`).

### MaxScale series and BSL Change Dates

Sources: `LICENSE.TXT` / `licenses/LICENSE<series>.TXT` on each branch and tag of https://github.com/mariadb-corporation/MaxScale (fetched via raw.githubusercontent.com), and the README licence table on branches `develop` and `24.02`.

| Series | Licence | Change Date (→ GPLv2+) | Status on 2026-10-14 |
|---|---|---|---|
| 21.06 | BSL 1.1 | 2024-06-03 | GPLv2+ |
| 22.08 | BSL 1.1 | 2025-09-12 | GPLv2+ |
| 23.02 | BSL 1.1 | 2026-03-20 | GPLv2+ |
| **23.08** (23.08.6 and later, incl. 23.08.13) | BSL 1.1 | **2026-09-21** | **GPLv2+ (converted 23 days ago)** |
| 23.08.0–23.08.5 (per-tag files) | BSL 1.1 | 2027-08-18 … **2028-02-27** (23.08.5) | Still BSL by the file's own text (see nuance) |
| 24.02 (24.02.2 and later; latest 24.02.9) | BSL 1.1 | 2027-04-10 (24.02.0 = 2028-02-27, 24.02.1 = 2028-04-03) | BSL |
| 24.08 (GitHub develop/tag 24.08.0 only) | BSL 1.1 | 2027-09-09 | BSL (never a mainstream GA line on Docker Hub) |
| **25.01, 25.10** | **Proprietary "MariaDB MaxScale License Terms" (2025-01-16)** | none | Closed source, paid subscription required |

Text of the 23.08 licence (`licenses/LICENSE2308.TXT`, branch 23.08, and the image's `/usr/share/maxscale/LICENSE.TXT` observed hands-on): Licensor MariaDB plc; Licensed Work "MariaDB MaxScale (TM) version 23.08"; Additional Use Grant "You may use the Licensed Work when your application uses the Licensed Work with a total of less than three server instances in production."; Change Date 2026-09-21; Change License "Version 2 or later of the GNU General Public License". BSL clause (lines 46-50): "Effective on the Change Date, or the fourth anniversary of the first publicly available distribution of a specific version of the Licensed Work under this License, whichever comes first, the Licensor hereby grants you rights under the terms of the Change License, and the rights granted in the paragraph above terminate."

**Nuances:**
1. **Rolling, then fixed, Change Dates.** Up to mid-2024, each patch release reset the Change Date about 4 years ahead. For example, 2.5.x had commits titled "Update Change Date" on every release, and the 2.5 file now reads 2027-10-10. The tags show the same pattern: 23.08.0 = 2027-08-18, 23.08.1 = 2027-09-19, 23.08.2/.3 = 2027-10-10, 23.08.4 = 2027-11-30, 23.08.5 = 2028-02-27. On 2024-05-29 MariaDB changed this (commits `93c416957e` "23.08.6 Adjust version in license – Should refer to the series and not…" and `844ab7ab50` for 24.02.2) to a single series-wide date: 23.08 = 2026-09-21, 24.02 = 2027-04-10. As a result, **23.08.13 converted to GPL earlier than the 23.08.5 image** that operators up to 26.6 used by default.
2. **Source availability.** The GitHub 23.08 branch carries `VERSION2308.cmake` patch 13 (last commit 2026-01-08), but there is no `maxscale-23.08.13` tag. The last tags are 23.08.12 and 24.02.8. Docker Hub has 23.08.13 / 23.08.13-2 / -ubi-2 (2026-03 to 2026-06). The 25.01 GitHub branch is docs-only (`25.01.x-docs`, last commit 2025-06-16) and its LICENSE.TXT still points at LICENSE2402. No 25.x source is public.
3. **Maintenance.** 23.08 is still receiving patches (23.08.13 in 2026; a search snippet mentions 23.08.14 docs). A search-result excerpt of MariaDB's Engineering Policy gives MaxScale 23.08 End of Standard Support and End of Life as **2027-08-01**. This is **unverified**: the PDF at mariadb.com returned 403. Any future 23.08.x patch would, under the post-2024 series policy, presumably carry the same 2026-09-21 date and so be GPLv2+ on release (unverified).
4. **Docker Hub `mariadb/maxscale` (checked 2026-10-14):** `latest` = `24.02` = `24.02.9-2` (same digest `sha256:a5614cf9…`), so `latest` is still BSL until 2027-04-10. `23.08` = `23.08.13-2` (digest `sha256:02171471…`). `25.10.2-trial` and `25.10.3-trial` exist. The Hub description says: "The MaxScale 25.10 trial image (25.10.2-trial) requires a licence key to run. Generate a licence key … `license_key=<license key contents>`".
5. **MaxScale 25.01+ terms** (https://legal.mariadb.com/agreements/maxscale/MariaDB_MaxScale_License_Terms_2025-01-16.pdf, read in full):
   - The licence is granted "Subject to Customer's payment of the applicable fees for Subscription Services".
   - Use is "limited solely to the use of MaxScale in combination with Software for which Customer has obtained Subscription Services". This means it may not be used with MariaDB servers that lack a subscription.
   - It prohibits managed-service or hosting use without written authorization, reverse engineering and modification.
   - MariaDB may audit and require yearly usage certification.
   - Publishing **benchmark results requires MariaDB's prior written approval** (§7).
   - The MariaDB FAQ page (https://mariadb.com/docs/platform/mariadb-faqs/database-proxies-and-routers/mariadb-maxscale) says: "As of January 16, 2025, MariaDB shifted the licensing for MaxScale 25.01 and later from the Business Source License (BSL) to a fully proprietary commercial license", and that 25.01+ is "closed-source and requires an active MariaDB Enterprise subscription for production use". The same page interprets the BSL grant as "free usage of MaxScale with up to two MariaDB backend database servers".

## 3. Practical implication (not legal advice)

- The BSL Additional Use Grant covers production use only when "your application uses the Licensed Work with a total of **less than three** server instances". MariaDB's own FAQ reads this as up to two backend database servers.
- The operator's recommended HA topologies are Galera with at least 3 nodes, or replication with a primary and at least 2 replicas (`docs/high_availability.md:5-9`). Both mean **3 or more backend servers behind MaxScale**, which is outside the free grant.
- **While a MaxScale version is in its BSL period, production use behind a 3-node cluster requires a commercial licence (subscription) from MariaDB plc.** This applies to 24.02.x until 2027-04-10, and to the 23.08.0–23.08.5 images by their per-version files. It also applied to the 23.08 series until 2026-09-21: every community-operator user who enabled MaxScale with ≥3 servers in production before that date needed a subscription.
- As of 2026-10-14, the **operator 26.10.x default (23.08.13-2) is past its Change Date and therefore GPLv2+**, so the restriction no longer applies to that image. The trade-off is that it is an older series with about 10 months of vendor maintenance left (EOL 2027-08-01, unverified). Moving to any newer MaxScale (24.02 BSL, 25.x proprietary) brings the restriction back, and for 25.x requires a subscription regardless of server count.
- MaxScale is not required for any core operator function, so a fully OSS deployment is possible: MariaDB Community + Galera + operator Services + operator auto-failover. It gives up read/write split, transaction replay, pooling and MaxScale-grade failover. The operator docs themselves recommend MaxScale "for production environments" (`docs/replication.md:218,264`).

## 4. Does the community operator warn about BSL?

- `docs/maxscale.md:6-7`:
  > [!IMPORTANT]
  > MaxScale 23.08 is licensed under [Business Source License](https://github.com/mariadb-corporation/MaxScale/blob/23.08/LICENSE.TXT). Make sure you understand the implications before using it!
- The warning does not mention the 3-server limit, the Change Date, or that 25.x is proprietary.
- **README.md has no licence warning.** It lists MaxScale as a feature, "[MaxScale](./docs/maxscale.md) as database proxy to load balance requests and perform failover/switchover operations" (`README.md:28`), plus "MaxScale compatibility: MaxScale >= 23.08" (`README.md:97-98`).
- `docs/high_availability.md:9,41-49` recommends MaxScale for production with no licence caveat. `docs/replication.md:218,264` also recommends MaxScale "for production environments" without a caveat.

## 5. Other non-OSS or commercial elements

**Community operator 26.10.1:**
- **Images.** Defaults are all OSS: `mariadb:12.3.3` (GPLv2), `prom/mysqld-exporter` (Apache-2.0), `ghcr.io/mariadb-operator/mariadb-operator` (MIT). The only non-OSS default is MaxScale, which is BSL or now GPL depending on version (`docs/docker.md:18-43`). README: "only compatible with official MariaDB images" (`README.md:92`).
- **Registries.** Older releases defaulted to `docker-registry{1,2,3}.mariadb.com`, which are now **deprecated** (`docs/docker.md:3-4`). These are public mirrors, not the customer registry. `docker.mariadb.com` (customer-only) is not referenced by the community operator.
- **No licence checks, licence keys, or telemetry/phone-home code.** The only "Telemetry" hit is the Azure SDK client option in `pkg/azure/client.go:326`.
- **Upsell.** The README and every release note say: "For enterprise users, see the MariaDB Enterprise Operator, a commercially supported Kubernetes operator from MariaDB with additional enterprise-grade features" (`README.md:137-139`; `docs/releases/RELEASE_26.10.0_HEADER.md.gotmpl:90-92`).
- **Backups.** mariadb-backup and mariadb-dump (GPLv2, inside the server image) and CSI VolumeSnapshots. No commercial backup tool is involved.

**MariaDB Enterprise Kubernetes Operator** (verified from mariadb.com docs `.md` endpoints, fetched 2026-10-14):
- It is a separate product with API group `enterprise.mariadb.com/v1alpha1`. The community API group is `k8s.mariadb.com`. Versions are 1.0.0 (GA 2025-04-23), 25.08, 25.10 LTS (25.10.6), 26.3.x and 26.6.4.
- **All images are in the private registry `docker.mariadb.com`**:
  - Operator: `docker.mariadb.com/mariadb-enterprise-operator`
  - Server: `docker.mariadb.com/enterprise-server` (10.6, 11.4, 11.8; `minimal`/`standard` hardened tiers on ubi-micro)
  - "MaxScale Enterprise": `docker.mariadb.com/maxscale` 25.01.x / 25.10.x
  - `docker.mariadb.com/nslcd` sidecar
  - It also lists the public `mariadb/maxscale` 23.08-ubi / 24.02-ubi as compatible.
  - Sources: https://mariadb.com/docs/tools/mariadb-enterprise-operator/docker-images.md
- Pulling requires `kubectl create secret docker-registry … --docker-server=docker.mariadb.com --docker-password=<customer-download-token>`. The token comes from the MariaDB Customer Portal, so in practice **a MariaDB subscription is required** (https://mariadb.com/docs/tools/mariadb-enterprise-operator/customer-access-to-docker-mariadb-com.md). The page says customers must authenticate, but I could not find an explicit "subscription required" sentence; that requirement follows from MariaDB's general terms.
- **Additions over the community operator:**
  - MariaDB Enterprise Server images
  - MaxScale 25.x (proprietary)
  - FIPS 140-3 mode (https://mariadb.com/docs/tools/mariadb-enterprise-operator/security/fips.md)
  - PAM/LDAP plugin with nslcd sidecar, and HashiCorp Vault key-management plugin (plugins/pam.md, plugins/hashicorp-key-management.md; both demonstrated on "MariaDB Enterprise Server")
  - Red Hat-certified UBI images and OpenShift OLM certification
  - ppc64le
  - Signed SBOMs and attestations
  - Root password rotation docs
  - Commercial support
  - Core features (topologies, backups, PITR, multi-cluster, MaxScale CR) mirror the community operator (introduction.md).
- **Migration from community** is via a script. MaxScale CRs "cannot be migrated … they need to be recreated" (migrations/migrate-community-operator-to-enterprise-operator.md).

## 6. Comparison: does any feature need a commercial licence?

- **Percona Operator for MySQL based on PXC:** operator Apache-2.0 (verified: `percona/percona-xtradb-cluster-operator/LICENSE`). PXC GPLv2, HAProxy GPLv2, ProxySQL GPLv3 (verified: `sysown/proxysql` LICENSE), XtraBackup GPLv2, PMM AGPLv3 (verified: `percona/pmm` LICENSE). **No feature requires a commercial licence**, and the proxy layer (HAProxy/ProxySQL) is fully OSS with no server-count limits.
- **Oracle MySQL Operator for Kubernetes:** operator UPL 1.0 (verified: `mysql/mysql-operator/LICENSE`, "MySQL Operator for Kubernetes 26.7.0 Community … Universal Permissive License"). MySQL Server Community and MySQL Router are GPLv2, and MySQL Shell dump backups are GPL. However, `spec.edition: enterprise` switches to `enterprise-server` / Router EE images (`mysqloperator/controller/innodbcluster/cluster_api.py:2064,2339`, `config.py:58`). **MySQL Enterprise Backup profiles (`meb`) require Enterprise Edition**: `cluster_objects.py:918-919` raises "A BackupProfile requires MySQL Enterprise Backup, but the cluster doesn't use Enterprise Edition". **Incremental backups are MEB-only** (`backup_api.py:334-335`). These are commercially licensed.
- **MariaDB community operator:** operator MIT, server and Galera GPLv2. **MaxScale features are BSL (≥3 servers needs a subscription while in the BSL period) or proprietary (25.x).** 23.08 is now GPL after its 2026-09-21 Change Date.

## URLs actually opened

- https://raw.githubusercontent.com/mariadb-corporation/MaxScale/{2.5,22.08,23.02,23.08,24.02,25.01,develop}/LICENSE.TXT and the `licenses/LICENSE*.TXT` targets; per-tag `maxscale-23.08.0`…`.12` and `maxscale-24.02.0`…`.8`, `maxscale-24.08.0`
- https://raw.githubusercontent.com/mariadb-corporation/MaxScale/{develop,24.02,25.01}/README.md ; GitHub API commit history for the licence files; `git ls-remote` of the MaxScale repo
- https://github.com/mariadb-corporation/MaxScale
- https://hub.docker.com/v2/repositories/mariadb/maxscale/tags and /mariadb/maxscale/ (description)
- https://legal.mariadb.com/agreements/maxscale/MariaDB_MaxScale_License_Terms_2025-01-16.pdf
- https://mariadb.com/docs/platform/mariadb-faqs/database-proxies-and-routers/mariadb-maxscale
- https://mariadb.com/docs/llms.txt ; https://mariadb.com/docs/tools/mariadb-enterprise-operator{,/introduction,/docker-images,/customer-access-to-docker-mariadb-com,/installation/helm,/security/fips,/plugins/pam,/plugins/hashicorp-key-management,/topologies/maxscale,/migrations/migrate-community-operator-to-enterprise-operator}.md
- https://raw.githubusercontent.com/mariadb-operator/mariadb-operator/{0.38.1,25.08.0,25.10.0,25.10.4,26.3.0,26.6.0,26.10.0,26.10.1}/deploy/charts/mariadb-operator/values.yaml
- https://github.com/mysql/mysql-operator (shallow clone), percona-xtradb-cluster-operator / pmm / proxysql LICENSE files
- 403, so unverified: the mariadb.com Engineering Policy PDFs (MaxScale 23.08 EOL date) and the mariadb.com blog "Introducing MaxScale trial"

Found during a documentation review of Percona Operator for MySQL (PXC) **1.20.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Problems
1. **8.4 status contradicts itself.** https://docs.percona.com/percona-operator-for-mysql/pxc/System-Requirements.html says PXC 8.4.8-8.1 is "(Tech preview)", while versions.html shows 8.4 without the label since 1.19.0 and the 1.20.0 release notes call 8.4 the "default and recommended version".
2. **backups.html is stale/inaccurate** (https://docs.percona.com/percona-operator-for-mysql/pxc/backups.html):
   - says native encryption and incremental backups are "not yet available in version 1.19.0" (current is 1.20.0);
   - says the sidecar uploads to "S3, Azure, or GCP" / "Only cloud storage backups (S3, Azure, GCP)", but there is no GCS storage type (operator.md: "Only s3, azure, and filesystem"; `pxc_types.go`).
3. **"Logical backup" wording.** The quickstart overview ("Set up and make a logical backup") and backup-tutorial.md ("make a logical backup") describe a logical backup; the operator only takes physical XtraBackup backups.
4. versions.html 1.20.0 row omits ProxySQL 3.0.6 (listed in the release notes and images table).

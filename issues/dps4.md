Found during a documentation review of Percona Operator for MySQL (Percona Server) **1.2.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Smaller issues
- Broken links: `https://docs.percona.com/legacy-documentation` without trailing slash returns 404 (images.md, update-*.md, release notes); XtraBackup `innovation-release` option-reference links (backup-cr.md, restore-cr.md, operator.md); the kube-state-metrics customresourcestate link.
- AKS is missing from the tested platforms although variables.yml defines `aksrecommended: '1.35'`; EKS versions differ from the PXC docs (up to 1.36 here vs 1.35).
- Release date for v0.10.0 is 2025-06-04 in variables.yml vs 2025-06-06 on GitHub.

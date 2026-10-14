Found during a documentation review of Percona Operator for MySQL (PXC) **1.20.0** against the live site on 2026-10-14 (and a hands-on test of the documented commands).

## Problem
https://docs.percona.com/percona-operator-for-mysql/pxc/compare.html ("Compare various solutions") is outdated and is used as competitive collateral:
- PXC operator listed with MySQL "5.7, 8.0"; 8.4 is the default since 1.19/1.20.
- Percona Server operator listed as "8.0" and without PITR; it supports 8.4 and has PITR (tech preview) and incremental backups.
- Oracle MySQL Operator listed as "Apache 2.0" licence and "8.0"; its LICENSE is **UPL 1.0** and it ships MySQL 8.4 / 9.7 / 26.7.
- The community **MariaDB operator** (mariadb-operator/mariadb-operator), now the most-starred MySQL-compatible operator, is missing.
- The PXC link on the page is `https:///` (broken).

## Fix
Refresh versions/licences/features, add MariaDB operator, fix the link. Happy to share our hands-on comparison data.

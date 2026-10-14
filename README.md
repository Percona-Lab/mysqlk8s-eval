# MySQL-compatible Kubernetes operators: hands-on evaluation

Scripts, manifests and raw results from a 2026-10-14 comparison of four operators on a 4-node k3s cluster (4 x Linode 4 GB):

| Operator | Version | Database | Proxy |
| --- | --- | --- | --- |
| Percona Operator for MySQL (PXC) | 1.20.0 | Percona XtraDB Cluster 8.4.8 | HAProxy |
| Percona Operator for MySQL (PS) | 1.2.0 | Percona Server 8.4.10, Group Replication | HAProxy |
| Oracle MySQL Operator | 26.7.0-2.3.0 | MySQL 26.7.0 InnoDB Cluster | MySQL Router |
| MariaDB Operator (community) | 26.10.1 | MariaDB 12.3.3 Galera | MaxScale 23.08.13 |

The written report (scorecard, failure/backup/day-2 results, MariaDB licensing analysis, issue log) is at
https://claude.ai/code/artifact/025f92a1-52c3-4b40-aaa5-511453cf09db

## Layout

- `bin/` – helpers
  - `linode.py`, `mk.py`, `fw.py` – create the 4 VMs and Cloud Firewall (needs `LINODE_TOKEN`)
  - `reset.sh` – set hostname before installing k3s
  - `probe.sh`, `mkprobe.sh` – in-cluster write probe: new connection + INSERT every 200 ms, logs `epoch_ms OK host id` / `FAIL error`
  - `run.sh` – runs one scenario against one operator, then computes the write outage (`analyze.py`) and checks acknowledged ids for lost writes (`lostcheck` in `h.sh`)
  - `h.sh` (sourced on the control-plane node), `rx.sh` (local wrapper) – helper functions
  - `partition.sh`, `sbwriter.sh` – network isolation of a node and local-socket write attempts (split-brain check); replace `NODE_IP_n` with your node IPs
  - `sysb.sh` – sysbench prepare (4 tables x 500,000 rows)
- `env/` – per-operator variables (container names, label selectors, operator deployment)
- `scen/` – scenarios: `delpod`, `kill9`, `delproxy`, `opdown`, `pvcloss`, `fullcrash`, `nodeoff`, `partition`, config change, backup/PITR per operator. `*.local` run from the workstation (they ssh to nodes); `*.sh` run on the control-plane node.
- `manifests/` – CRs actually used (`*-orig.yaml` are the vendors' defaults). Secrets are replaced with `CHANGE_ME_*`.
- `results/` – raw logs per operator and scenario (`<operator>_<scenario>.log`), probe logs, footprints, and evidence files for the main issues:
  - `pxc_pitr_failure.txt` – PXC PITR hang (duplicate key, GTID set behind data)
  - `mariadb_nil_uuid.txt`, `mdb-galera-*.log` – MariaDB Galera nil state UUID after full crash
  - `mariadb_restore.log` – MariaDB in-place logical restore breaking privilege tables on 2/3 nodes
- `notes/docs_review.md` – documentation review, feature matrix, doc defects and scores
- `notes/mariadb_licensing.md` – MariaDB operator / MaxScale licensing analysis (not legal advice)

## Usage

```bash
export LINODE_TOKEN=...
python3 bin/mk.py && python3 bin/fw.py            # 4 VMs + firewall
# install k3s server on mk-cp (tainted) and agents on mk-w1..3, deploy manifests/s3.yaml
# install an operator + cluster per its docs, create probe/sbtest users, start the probe:
bash mkprobe.sh pxc pxc cluster1-haproxy.pxc probe ProbePass123 percona/percona-server:8.4
bin/run.sh pxc_kill9 pxc pxc scen/kill9.local      # name, namespace, probe, scenario
```

Each scenario ran once per operator (MariaDB full crash twice); treat times as indicative. Storage was node-local (k3s local-path).

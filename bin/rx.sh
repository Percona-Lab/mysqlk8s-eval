# rx "<remote cmd>" : run on mk-cp with helpers (used by .local scenarios)
rx(){ timeout ${RXT:-1000} ssh -n -o ServerAliveCountMax=3 -F ~/mysqlk8s/ssh_config ${CP:-mk-cp} "$OPENV; NS=$NS; source h.sh; $1"; }
eval "$OPENV"

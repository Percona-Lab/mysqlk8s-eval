kubectl -n mariadb patch mariadb mariadb-galera --type=merge -p '{"spec":{"image":"mariadb:12.3.3"}}'; T2=$(date +%s); sleep 30
until [ "$(kubectl -n mariadb get mariadb mariadb-galera -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}")" = True ] && [ "$(kubectl -n mariadb get sts mariadb-galera -o jsonpath={.status.updatedReplicas})" = 3 ]; do sleep 5; [ $(( $(date +%s)-T2 )) -gt 1200 ] && break; done; echo DB_UPGRADED $(( $(date +%s)-T2 ))s
for p in 0 1 2; do echo "galera-$p $(sql mariadb-galera-$p mariadb 'select version()')"; done
kubectl -n mariadb patch maxscale maxscale-galera --type=merge -p '{"spec":{"image":"mariadb/maxscale:23.08.13-2"}}'; T3=$(date +%s); sleep 30
until [ "$(kubectl -n mariadb get sts maxscale-galera -o jsonpath={.status.updatedReplicas})" = 3 ] && [ "$(kubectl -n mariadb get maxscale maxscale-galera -o jsonpath="{.status.conditions[?(@.type==\"Ready\")].status}")" = True ]; do sleep 5; [ $(( $(date +%s)-T3 )) -gt 900 ] && break; done; echo MAXSCALE_UPGRADED $(( $(date +%s)-T3 ))s
kubectl -n mariadb get pods | grep -E "galera|maxscale"

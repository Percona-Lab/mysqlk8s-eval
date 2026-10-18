# run on mk-cp: sample connections on each Oracle member every 10s for $1 seconds
cd /root; source h.sh; OP=oracle; NS=oracle; E=$(( $(date +%s)+$1 ))
while [ $(date +%s) -lt $E ]; do for p in 0 1 2; do
  r=$(timeout 8 bash -c "source h.sh; OP=oracle; NS=oracle; sql mycluster-$p mysql \"select concat(@@hostname,' role=',(select member_role from performance_schema.replication_group_members where member_id=@@server_uuid),' conns=',count(*),' max=',@@max_connections,' top=',(select group_concat(x) from (select concat(user,':',command,':',coalesce(state,''),'=',count(*)) x from information_schema.processlist group by user,command,state order by count(*) desc limit 4) t)) from information_schema.processlist\"" 2>&1 | tail -1)
  echo "$(date -u +%T) $r"; done; sleep 10; done

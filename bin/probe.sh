#!/bin/bash
# env: H host, PU user, PP pass, CLI mysql|mariadb ; prints "epoch_ms OK host id" / "epoch_ms FAIL err" every ~200ms
CLI=${CLI:-mysql}
while true; do
  t=$(date +%s%3N)
  r=$(timeout 4 $CLI -h "$H" -P ${PORT:-3306} -u "$PU" -p"$PP" --connect-timeout=2 ${EXTRA} -NBe "insert into probe.t(ts,src) values (now(6),'p'); select concat(@@hostname,' ',last_insert_id())" 2>&1 | grep -v 'Using a password' | tail -1)
  if [[ "$r" =~ ^[a-zA-Z0-9._-]+\ [0-9]+$ ]]; then echo "$t OK $r"; else echo "$t FAIL ${r:0:200}"; fi
  sleep 0.2
done

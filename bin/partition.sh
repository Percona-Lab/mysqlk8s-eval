#!/bin/bash
# isolate this node from all other main-cluster nodes for $1 s (MODE=both|out); FLAP=n cycles of $1 s on/off
MY=$(hostname -I); IPS="<MK_CP_PUBIP> <MK_CP_PRIVIP> <MK_W1_PUBIP> <MK_W1_PRIVIP> <MK_W2_PUBIP> <MK_W2_PRIVIP> <MK_W3_PUBIP> <MK_W3_PRIVIP> <MK_W4_PUBIP> <MK_W4_PRIVIP> <MK_W5_PUBIP> <MK_W5_PRIVIP>"; MODE=${MODE:-both}
on(){ for ip in $IPS; do echo "$MY" | grep -qw $ip && continue; [ $MODE = both ] && { iptables -I INPUT -s $ip -j DROP; iptables -I FORWARD -s $ip -j DROP; }; iptables -I OUTPUT -d $ip -j DROP; iptables -I FORWARD -d $ip -j DROP; done; }
off(){ for ip in $IPS; do echo "$MY" | grep -qw $ip && continue; [ $MODE = both ] && { iptables -D INPUT -s $ip -j DROP; iptables -D FORWARD -s $ip -j DROP; }; iptables -D OUTPUT -d $ip -j DROP; iptables -D FORWARD -d $ip -j DROP; done; }
for c in $(seq 1 ${FLAP:-1}); do on; echo PART_ON $(date +%s%3N); sleep $1; off; echo PART_OFF $(date +%s%3N); [ ${FLAP:-1} -gt 1 ] && sleep $1; done

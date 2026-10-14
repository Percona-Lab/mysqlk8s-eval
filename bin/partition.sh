#!/bin/bash
# isolate this node from all other cluster nodes for $1 s (own IPs are excluded at runtime); ssh from outside keeps working
MY=$(hostname -I); IPS="NODE_IP_0 NODE_IP_1 NODE_IP_2 NODE_IP_3 NODE_IP_4 NODE_IP_5 NODE_IP_6 NODE_IP_7"
for ip in $IPS; do echo "$MY" | grep -qw $ip && continue; for c in INPUT FORWARD; do iptables -I $c -s $ip -j DROP; done; for c in OUTPUT FORWARD; do iptables -I $c -d $ip -j DROP; done; done
echo PART_ON $(date +%s%3N); sleep $1
for ip in $IPS; do echo "$MY" | grep -qw $ip && continue; for c in INPUT FORWARD; do iptables -D $c -s $ip -j DROP; done; for c in OUTPUT FORWARD; do iptables -D $c -d $ip -j DROP; done; done; echo PART_OFF $(date +%s%3N)

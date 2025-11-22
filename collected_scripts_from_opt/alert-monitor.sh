#!/usr/bin/env bash
set -Eeuo pipefail
THRESHOLD_CPU=80
THRESHOLD_MEMORY=85
THRESHOLD_DISK=90
ALERT_FILE="/var/log/smartfrind/alerts.log"
log_alert(){ echo "$(date '+%F %T') $1" >> "$ALERT_FILE"; }
CPU=$(awk -F'[, ]+' '/Cpu\(s\)/{print $2}' <(LANG=C top -bn1) | cut -d% -f1 | head -1)
MEM=$(free | awk '/Mem/{printf("%.0f",$3/$2*100)}')
DSK=$(df / | awk 'NR==2{gsub("%","",$5);print $5}')
[ "${CPU:-0}" != "" ] && (( $(echo "$CPU > $THRESHOLD_CPU" | bc -l) )) && log_alert "HIGH_CPU ${CPU}%"
[ "${MEM:-0}" -gt "$THRESHOLD_MEMORY" ] && log_alert "HIGH_MEM ${MEM}%"
[ "${DSK:-0}" -gt "$THRESHOLD_DISK" ] && log_alert "HIGH_DSK ${DSK}%"

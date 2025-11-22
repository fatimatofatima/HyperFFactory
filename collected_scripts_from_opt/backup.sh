#!/usr/bin/env bash
set -Eeuo pipefail
B="/var/lib/smartfrind/backup"
T=$(date +%Y%m%d_%H%M%S)
L="/var/log/smartfrind/backup.log"
mkdir -p "$B"
log(){ echo "[$(date '+%F %T')] $1" >> "$L"; }
log "start $T"
cp -a /etc/smartfrind/config.env "$B/config.env.$T" 2>/dev/null && log "config saved" || log "config miss"
cp -a /var/lib/smartfrind/secret.key "$B/secret.key.$T" 2>/dev/null && log "secret saved" || log "secret miss"
[ -f /var/lib/smartfrind/audit.jsonl ] && tail -1000 /var/lib/smartfrind/audit.jsonl > "$B/audit.$T.jsonl"
find "$B" -type f -mtime +7 -delete

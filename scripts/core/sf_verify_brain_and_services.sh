#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== SmartFriend + FFactory structure & services check ====="
echo

########################################
# 1) قواعد البيانات الفعّالة
########################################
log "1) قواعد البيانات:"
for base in /opt/smartfriend-suite/var/db /opt/ffactory/var/db; do
  if [ -d "$base" ]; then
    echo ">> $base"
    find "$base" -maxdepth 1 -type f -name '*.db' 2>/dev/null | while read -r db; do
      size=$(du -h "$db" | cut -f1)
      echo "   - $db ($size)"
    done
    echo
  fi
done

########################################
# 2) حالة الخدمات (systemd)
########################################
log "2) حالة الخدمات (systemd):"
SERVICES=(
  sf-health.service
  sf-memory.service
  sf-unified.service
  sf-bot.service
  ff-healthd.service
  ff-core.service
)

for s in "${SERVICES[@]}"; do
  if systemctl list-unit-files "$s" &>/dev/null; then
    state=$(systemctl is-active "$s" 2>/dev/null || echo "unknown")
    echo "   - $s : $state"
  fi
done
echo

########################################
# 3) فحص HTTP health
########################################
log "3) Health HTTP endpoints:"

check_http(){
  name="$1"
  url="$2"
  if command -v curl >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -w '%{http_code}' "$url" || echo "000")
    echo "   - $name @ $url => HTTP $code"
  else
    echo "   - $name @ $url => curl غير متوفر"
  fi
}

check_http "sf-health"   "http://127.0.0.1:8210/health"
check_http "sf-memory"   "http://127.0.0.1:8214/health"
check_http "sf-unified"  "http://127.0.0.1:8220/health"
check_http "ff-healthd"  "http://127.0.0.1:9191/health"

echo
log "===== DONE ====="

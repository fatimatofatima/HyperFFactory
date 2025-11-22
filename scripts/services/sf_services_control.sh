#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

if [ $# -lt 1 ]; then
  echo "Usage: $0 {status|start|stop|restart}"
  exit 1
fi

ACTION="$1"
case "$ACTION" in
  status|start|stop|restart) ;;
  *)
    error "أمر غير معروف: $ACTION (المتاح: status|start|stop|restart)"
    exit 1
    ;;
esac

SERVICES=(
  smartfriend-smartcore.service
  smartfriend-unified.service
  sf-health.service
  smartfriend-health.service
  smartfriend-dashboard.service
  ffactory_main.service
  ffactory_gateway.service
  ff-health.service
  smartfrind-gateway.service
  smartfrind-bot.service
)

have_unit() {
  systemctl list-unit-files --type=service | awk '{print $1}' | grep -qx "$1"
}

log "تنفيذ أمر '$ACTION' على خدمات SmartFriend Stack"

for svc in "${SERVICES[@]}"; do
  if have_unit "$svc"; then
    case "$ACTION" in
      status)
        echo "----------------------------------------"
        echo "🔎 حالة الخدمة: $svc"
        systemctl --no-pager -n 5 status "$svc" || true
        ;;
      start|stop|restart)
        log "[$ACTION] $svc"
        if ! systemctl "$ACTION" "$svc"; then
          warn "فشل $ACTION للخدمة $svc"
        fi
        ;;
    esac
  else
    warn "تخطي (لا توجد خدمة باسم): $svc"
  fi
done

if [ "$ACTION" = "status" ]; then
  echo "----------------------------------------"
  log "فحص سريع للبورتات المهمة"
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn | egrep ':(8000|8170|8211|8214|8220|5432|11434)\b' || warn "لا توجد بورتات مطابقة حالياً"
  else
    netstat -tulpn 2>/dev/null | egrep ':(8000|8170|8211|8214|8220|5432|11434)\b' || warn "لا توجد بورتات مطابقة حالياً"
  fi
fi

log "انتهى تنفيذ أمر '$ACTION'"

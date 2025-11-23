#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# HyperFFactory – SmartFriend Suite Services Orchestrator
# ---------------------------------------------------------

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

LOG_FILE="$REPORT_DIR/hf_smartfriend_services_$(date +%Y%m%d_%H%M%S).log"

# الخدمات المستهدفة داخل SmartFriend Suite
SERVICES=(
  sf-core.service
  sf-web.service
  sf-health.service
  sf-memory.service
  sf-bot.service
)

log() {
  echo "[$(date +%F_%T)] $*" | tee -a "$LOG_FILE"
}

usage() {
  cat <<USAGE
استخدام:
  hf_smartfriend_services.sh status      # عرض حالة الخدمات
  hf_smartfriend_services.sh start       # تشغيل الخدمات بالترتيب
  hf_smartfriend_services.sh stop        # إيقاف الخدمات بالترتيب العكسي
  hf_smartfriend_services.sh restart     # إعادة تشغيل (stop ثم start)
USAGE
}

cmd="${1:-status}"

case "$cmd" in
  status)
    log "📊 حالة خدمات SmartFriend Suite:"
    for svc in "${SERVICES[@]}"; do
      if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
        state=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
        enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
        log "  - $svc : active=$state, enabled=$enabled"
      else
        log "  - $svc : غير موجود (unit غير معرف)"
      fi
    done
    ;;

  start)
    log "🚀 تشغيل خدمات SmartFriend Suite (start)..."
    for svc in "${SERVICES[@]}"; do
      if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
        log "▶ systemctl start $svc"
        systemctl start "$svc" || log "⚠️ فشل تشغيل $svc (راجع journalctl)"
      else
        log "⚪ تخطي $svc (غير موجود)"
      fi
    done
    ;;

  stop)
    log "⏹ إيقاف خدمات SmartFriend Suite (stop)..."
    # إيقاف بالترتيب العكسي
    for (( idx=${#SERVICES[@]}-1 ; idx>=0 ; idx-- )); do
      svc="${SERVICES[$idx]}"
      if systemctl list-unit-files "$svc" >/dev/null 2>&1; then
        log "▶ systemctl stop $svc"
        systemctl stop "$svc" || log "⚠️ فشل إيقاف $svc (راجع journalctl)"
      else
        log "⚪ تخطي $svc (غير موجود)"
      fi
    done
    ;;

  restart)
    log "🔁 إعادة تشغيل خدمات SmartFriend Suite..."
    "$0" stop
    "$0" start
    ;;

  *)
    usage
    exit 1
    ;;
esac

log "✅ انتهى تنفيذ hf_smartfriend_services.sh بالأمر: $cmd"

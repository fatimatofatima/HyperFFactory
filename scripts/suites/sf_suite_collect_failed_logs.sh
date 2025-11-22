#!/usr/bin/env bash
set -Eeuo pipefail

REPORT_DIR="/opt/smartfriend-suite/reports"
TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_suite_failed_services_logs_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*"; }

main() {
  log "جمع لوجات الخدمات الفاشلة/المعلقة"
  echo "============================================================" > "$REPORT"
  
  # الخدمات في حالة مشكلة
  PROBLEM_SERVICES=(
    sf-unified.service
    sf-memory.service
    sf-health.service
    sf-spider.service
    sf-audit-bot.service
    sf-smartfactory.service
    sf-cognitive.service
    sf-learning.service
  )
  
  for service in "${PROBLEM_SERVICES[@]}"; do
    if systemctl is-active "$service" &>/dev/null || \
       systemctl is-failed "$service" &>/dev/null; then
      echo "=== $service ===" >> "$REPORT"
      journalctl -u "$service" -n 30 --no-pager 2>/dev/null >> "$REPORT" || echo "لا توجد سجلات" >> "$REPORT"
      echo -e "\n\n" >> "$REPORT"
    fi
  done
  
  log "تم إنشاء التقرير: $REPORT"
}

main

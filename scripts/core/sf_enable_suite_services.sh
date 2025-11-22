#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN] ${NC}$*" >&2; }
error() { echo -e "${RED}[$(date '+%F %T')] [ERROR] ${NC}$*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK] ${NC}$*"; }

if [[ "$EUID" -ne 0 ]]; then
  error "يجب تشغيل السكربت بصلاحيات root."
  exit 1
fi

log "=== تفعيل خدمات SmartFriend Suite فقط (بدون لمس ffactory/factory) ==="

# 1) الخدمات الحية الأساسية التي نريدها شغالة دائماً
PRIMARY_SERVICES=(
  sf-core.service
  sf-memory.service
  sf-bot-dev.service
  sf-bot-model.service
  smartfrind-api.service
  smartfrind-envwatch.service
  smartfrind-runner.service
)

log "1) تفعيل وتشغيل الخدمات الأساسية:"
for unit in "${PRIMARY_SERVICES[@]}"; do
  if systemctl list-unit-files "$unit" &>/dev/null; then
    log " - $unit: enable + restart"
    systemctl enable "$unit" >/dev/null 2>&1 || warn "تعذر enable لـ $unit (قد يكون مفعّل مسبقاً)"
    systemctl restart "$unit" >/dev/null 2>&1 || warn "تعذر restart لـ $unit (تحقق لاحقاً من logs)"
  else
    warn "الوحدة غير موجودة (تجاهل): $unit"
  fi
done

# 2) تفعيل جميع التايمرز الخاصة بالسويت (sf-*.timer, smartfrind-*.timer)
log "2) تفعيل جميع تايمرز SmartFriend Suite:"
mapfile -t SUITE_TIMERS < <(systemctl list-unit-files 'sf-*.timer' 'smartfrind-*.timer' --no-legend 2>/dev/null | awk '{print $1}' | sort -u)

if [[ "${#SUITE_TIMERS[@]}" -eq 0 ]]; then
  warn "لم يتم العثور على أي تايمرز sf-*.timer أو smartfrind-*.timer"
else
  for t in "${SUITE_TIMERS[@]}"; do
    log " - تفعيل التايمر: $t"
    systemctl enable "$t" >/dev/null 2>&1 || warn "تعذر enable لـ $t"
    systemctl start "$t"  >/dev/null 2>&1 || warn "تعذر start لـ $t (قد يعمل عند الموعد المجدول فقط)"
  done
fi

# 3) عرض ملخص لحالة خدمات السويت
log "3) ملخص حالة خدمات SmartFriend Suite (sf-*, smartfrind-*)"

echo
echo "🟢 الخدمات النشطة (active/running):"
systemctl list-units 'sf-*.service' 'smartfrind-*.service' --no-pager --no-legend 2>/dev/null \
  | awk '$4=="running"{printf "  %s (%s)\n",$1,$4}'

echo
echo "🔴 الخدمات الفاشلة أو المتوقفة بحالة failed:"
systemctl list-units 'sf-*.service' 'smartfrind-*.service' --no-pager --no-legend 2>/dev/null \
  | awk '$4=="failed"{printf "  %s (%s)\n",$1,$4}'

echo
echo "⏱ التايمرز المفعّلة لـ SmartFriend Suite:"
systemctl list-timers --all --no-pager 2>/dev/null \
  | grep -E 'sf-|smartfrind-' || echo "  (لا يوجد تايمرز ظاهرة الآن)"

ok "اكتمل تفعيل خدمات SmartFriend Suite (بدون لمس ffactory/factory)."

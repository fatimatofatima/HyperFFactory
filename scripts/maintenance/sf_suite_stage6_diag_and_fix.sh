#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [SUCCESS]${NC} $*"; }
sep(){ echo -e "${CYAN}────────────────────────────────────────────────────────────${NC}"; }

AUTO_RESTART="${AUTO_RESTART:-0}"
REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"

log "=== Stage6: تشخيص أعطال خدمات السويت + فحص حالة الكور ==="
log "AUTO_RESTART = $AUTO_RESTART (0 = تشخيص فقط، 1 = محاولة Restart آلي للخدمات الآمنة)"
echo

########################################################################
# 1) تعريف مجموعات الخدمات
########################################################################
# خدمات الكور الحرجة (يجب أن تكون شغالة)
CRITICAL_SERVICES=(
  sf-core.service
  smartfrind-api.service
  smartfrind-gateway.service
  smartfrind-qa.service
  smartfrind-monitor.service
  smartfrind-runner.service
  smartfrind-envwatch.service
)

# خدمات SmartFriend/SmartFrind التي سنسمح بإعادة تشغيلها آليًا (ليست Telegram Bots)
SAFE_RESTART_PREFIXES=(
  "sf-"
  "smartfrind-"
)
# استثناءات: بوتات تيليجرام
BLOCKED_RESTART_SERVICES=(
  sf-bot.service
  sf-telegram.service
  sf-telegram-audit.service
  smartfrind-bot.service
)

# خدمات سيستم عامة نتابعها فقط (لا نعدّلها)
SYSTEM_FAILED_SERVICES=(
  logrotate.service
  update-notifier-download.service
)

########################################################################
# دوال مساعدة
########################################################################
is_in_list() {
  local item="$1"; shift
  local x
  for x in "$@"; do
    if [[ "$x" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

starts_with_any_prefix() {
  local item="$1"; shift
  local p
  for p in "$@"; do
    if [[ "$item" == "$p"* ]]; then
      return 0
    fi
  done
  return 1
}

dump_unit_report() {
  local unit="$1"
  local outfile="$REPORT_DIR/stage6_${unit}.log"
  sep
  log "📄 تجميع تقرير للخدمة: $unit -> $outfile"

  {
    echo "===== systemctl status $unit ====="
    systemctl status "$unit" --no-pager || true
    echo
    echo "===== journalctl -u $unit (آخر 40 سطر) ====="
    journalctl -u "$unit" -n 40 --no-pager || true
  } > "$outfile"

  success "تم حفظ تقرير $unit في $outfile"
}

try_restart_unit() {
  local unit="$1"

  if [[ "$AUTO_RESTART" != "1" ]]; then
    warn "    - تخطّي Restart لـ $unit (AUTO_RESTART=0)"
    return 0
  fi

  # ممنوع إعادة تشغيل بوتات تيليجرام من السكربت
  if is_in_list "$unit" "${BLOCKED_RESTART_SERVICES[@]}"; then
    warn "    - تخطّي Restart لـ $unit (Telegram/Bot – يدوي فقط)"
    return 0
  fi

  # لا نحاول Restart لو مش من عائلة sf- أو smartfrind-
  if ! starts_with_any_prefix "$unit" "${SAFE_RESTART_PREFIXES[@]}"; then
    warn "    - تخطّي Restart لـ $unit (خدمة ليست من السويت)"
    return 0
  fi

  log "    - systemctl restart $unit"
  if systemctl restart "$unit"; then
    success "    - Restart ناجح لـ $unit"
  else
    error "    - فشل Restart لـ $unit – راجع التقرير في $REPORT_DIR/stage6_${unit}.log"
  fi
}

########################################################################
# 2) تجميع قائمة الخدمات الفاشلة
########################################################################
log "1️⃣ الخدمات الفاشلة الحالية (جميع النظام):"
sep
FAILED_UNITS_RAW=$(systemctl list-units --type=service --state=failed --no-legend --no-pager | awk '{print $1}')
echo "$FAILED_UNITS_RAW"
echo

########################################################################
# 3) تشخيص الخدمات الفاشلة
########################################################################
log "2️⃣ إنشاء تقارير تفصيلية لكل خدمة فاشلة..."
sep

for unit in $FAILED_UNITS_RAW; do
  dump_unit_report "$unit"
done
echo

########################################################################
# 4) تصنيف الخدمات الفاشلة (System vs SmartFriend)
########################################################################
log "3️⃣ تصنيف الأعطال:"
sep

SYSTEM_FAILED=()
SUITE_FAILED=()
OTHER_FAILED=()

for unit in $FAILED_UNITS_RAW; do
  if is_in_list "$unit" "${SYSTEM_FAILED_SERVICES[@]}"; then
    SYSTEM_FAILED+=("$unit")
  elif starts_with_any_prefix "$unit" "sf-" "smartfrind-" "smartfriend-"; then
    SUITE_FAILED+=("$unit")
  else
    OTHER_FAILED+=("$unit")
  fi
done

log "   • أعطال نظام عامة (OS): ${SYSTEM_FAILED[*]:-"(لا شيء)"}"
log "   • أعطال SmartFriend Suite: ${SUITE_FAILED[*]:-"(لا شيء)"}"
log "   • أعطال أخرى: ${OTHER_FAILED[*]:-"(لا شيء)"}"
echo

########################################################################
# 5) فحص حالة خدمات الكور الحرجة
########################################################################
log "4️⃣ فحص حالة خدمات الكور الحرجة في السويت:"
sep

MISSING_CRITICAL=()
for svc in "${CRITICAL_SERVICES[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    warn "   - $svc :: غير موجود (Unit غير معرف)"
    MISSING_CRITICAL+=("$svc")
    continue
  fi
  state="$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")"
  enabled_state="$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")"

  case "$state" in
    active)  icon="🟢" ;;
    activating) icon="🟡" ;;
    failed) icon="🔴" ;;
    inactive) icon="⚪" ;;
    *) icon="⚫" ;;
  esac

  log "   - $svc :: الحالة=$icon $state / التفعيل=$enabled_state"

  # لو الخدمة حرجة وحالتها failed أو inactive، حاول Restart (لو مسموح)
  if [[ "$state" == "failed" || "$state" == "inactive" ]]; then
    try_restart_unit "$svc"
  fi
done
echo

########################################################################
# 6) محاولة Restart للخدمات الفاشلة الخاصة بالسويت (غير الحرجة)
########################################################################
log "5️⃣ التعامل مع أعطال السويت (غير الكور):"
sep

if [[ "${#SUITE_FAILED[@]}" -eq 0 ]]; then
  log "   - لا توجد خدمات سويت فاشلة حاليًا."
else
  for unit in "${SUITE_FAILED[@]}"; do
    log "   - معالجة $unit:"
    # تقريريًا فقط – Restart اختياري حسب AUTO_RESTART
    try_restart_unit "$unit"
  done
fi
echo

########################################################################
# 7) ملخص نهائي
########################################################################
log "6️⃣ ملخص Stage6:"
sep
log "   • تم إنشاء تقارير في المجلد: $REPORT_DIR"
log "   • لتفحص تقرير خدمة معينة استخدم مثلاً:"
log "       less $REPORT_DIR/stage6_sf-backup.service.log"
log "       less $REPORT_DIR/stage6_smartfrind-autolearn.service.log"
echo
log "   • الخدمات الحرجة تم فحصها ومحاولة إصلاحها (لو AUTO_RESTART=1)."
log "   • بوتات تيليجرام لم يتم لمسها، تحتاج ضبط توكن يدوي ثم restart يدوي."
echo

success "Stage6 اكتمل. التشخيص موجود في $REPORT_DIR، وإصلاح محدود حسب AUTO_RESTART."

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

log "=== SmartFriend Suite - Check / Fix / Run ==="
echo

#############################################
# 1) تجميع الخدمات الفاشلة للسيوت فقط
#############################################
list_failed_units() {
  systemctl list-units --type=service --state=failed --no-legend --no-pager 2>/dev/null \
    | awk '{
        for (i=1;i<=NF;i++) {
          if ($i ~ /\.service$/) {
            print $i;
            break;
          }
        }
      }' \
    | grep -E '^(sf-|smartfrind-|smartfriend-)' || true
}

log "1) فحص الخدمات الفاشلة..."
FAILED_UNITS="$(list_failed_units)"

if [ -z "$FAILED_UNITS" ]; then
  success "لا توجد خدمات سيوت فاشلة حالياً."
else
  echo "الخدمات الفاشلة:" 
  echo "$FAILED_UNITS"
fi
echo

FIXED=()
STILL_FAILED=()

#############################################
# 2) تشخيص وإعادة تشغيل الخدمات الفاشلة
#############################################
for unit in $FAILED_UNITS; do
  log "🔍 تشخيص الخدمة: $unit"
  journalctl -u "$unit" -n 10 --no-pager 2>&1 || true
  echo
  log "محاولة restart لـ $unit ..."
  if systemctl restart "$unit" 2>/dev/null; then
    sleep 1
    state="$(systemctl is-active "$unit" 2>/dev/null || echo unknown)"
    if [ "$state" = "active" ]; then
      success "الخدمة $unit أصبحت active."
      FIXED+=("$unit")
    else
      warn "الخدمة $unit ما زالت في حالة: $state."
      STILL_FAILED+=("$unit")
    fi
  else
    error "فشل restart لـ $unit."
    STILL_FAILED+=("$unit")
  fi
  echo
done

#############################################
# 3) تشغيل الخدمات الأساسية للسيوت
#############################################
log "3) تشغيل الخدمات الأساسية للسيوت..."

CORE_SERVICES=(
  sf-core.service
  smartfrind-api.service
  smartfrind-qa.service
  smartfrind-gateway.service
  smartfrind-runner.service
  smartfrind-envwatch.service
  sf-web.service
)

for svc in "${CORE_SERVICES[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    continue
  fi
  log "   ▸ معالجة $svc ..."
  enabled_state="$(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)"
  if [ "$enabled_state" = "enabled" ] || [ "$enabled_state" = "static" ]; then
    if systemctl restart "$svc" 2>/dev/null; then
      success "   $svc restarted (enabled=$enabled_state)"
    else
      warn "   فشل restart لـ $svc"
    fi
  else
    if systemctl start "$svc" 2>/dev/null; then
      success "   $svc started (enabled=$enabled_state)"
    else
      warn "   فشل start لـ $svc"
    fi
  fi
done
echo

#############################################
# 4) تشغيل خدمات البنية التحتية المرتبطة
#############################################
log "4) تشغيل خدمات البنية التحتية المرتبطة..."

INFRA_SERVICES=(
  deepseek-api.service
  factory-gw.service
  ff-healthd.service
)

for svc in "${INFRA_SERVICES[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    continue
  fi
  log "   ▸ معالجة $svc ..."
  enabled_state="$(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)"
  if [ "$enabled_state" = "enabled" ] || [ "$enabled_state" = "static" ]; then
    if systemctl restart "$svc" 2>/dev/null; then
      success "   $svc restarted"
    else
      warn "   فشل restart لـ $svc"
    fi
  else
    if systemctl start "$svc" 2>/dev/null; then
      success "   $svc started"
    else
      warn "   فشل start لـ $svc"
    fi
  fi
done
echo

#############################################
# 5) بوتات تيليجرام (بدون لمس التوكنات)
#############################################
log "5) فحص وتشغيل بوتات تيليجرام (بدون تعديل توكنات)..."

TELEGRAM_SERVICES=(
  sf-bot.service
  sf-telegram.service
  sf-telegram-audit.service
  smartfrind-bot.service
)

for svc in "${TELEGRAM_SERVICES[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    continue
  fi
  state="$(systemctl is-active "$svc" 2>/dev/null || echo unknown)"
  if [ "$state" != "active" ]; then
    log "   ▸ محاولة تشغيل $svc (حالة حالية: $state)..."
    if systemctl restart "$svc" 2>/dev/null || systemctl start "$svc" 2>/dev/null; then
      success "   $svc شغّال الآن."
    else
      warn "   فشل تشغيل $svc (غالباً مشكلة توكن/بيئة)."
    fi
  else
    success "   $svc already active."
  fi
done
echo

#############################################
# 6) فحص البورتات الأساسية
#############################################
log "6) فحص البورتات الأساسية (8000 / 8170 / 8220 / 8383)..."

for port in 8000 8170 8220 8383; do
  if ss -tulpn 2>/dev/null | grep -q ":$port "; then
    success "   البورت $port مفتوح."
  else
    warn "   البورت $port غير مفتوح أو الخدمة غير شغالة."
  fi
done
echo

#############################################
# 7) ملخص نهائي
#############################################
log "7) الملخص النهائي:"

if [ "${#FIXED[@]}" -gt 0 ]; then
  echo "   ✅ خدمات تم إصلاحها:" 
  for u in "${FIXED[@]}"; do
    echo "      - $u"
  done
fi

if [ "${#STILL_FAILED[@]}" -gt 0 ]; then
  echo "   ❌ خدمات ما زالت تحتاج مراجعة يدويّة:"
  for u in "${STILL_FAILED[@]}"; do
    echo "      - $u"
  done
  echo "   استخدم الأمر التالي لكل خدمة:"
  echo "      journalctl -u <service> -n 50 --no-pager"
else
  success "   لا توجد خدمات فاشلة متبقية داخل السيوت."
fi

success "انتهى فحص/إصلاح/تشغيل SmartFriend Suite."

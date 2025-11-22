#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

log "=== SmartFriend Suite – تفعيل خدمات السيوت بدون لمس ffactory ==="

# 1) جلب كل وحدات السيوت (sf-*, smartfriend-*, smartfrind-*)
log "[*] جمع قائمة الوحدات المتعلقة بالسيوت..."
SUITE_UNITS="$(systemctl list-unit-files 'sf-*.service' 'smartfriend-*.service' 'smartfrind-*.service' --no-legend 2>/dev/null | awk '{print $1}' || true)"

if [[ -z "${SUITE_UNITS}" ]]; then
  warn "لم يتم العثور على وحدات sf-* أو smartfriend-* أو smartfrind-*."
else
  log "الوحدات المكتشفة:"
  echo "${SUITE_UNITS}" | sed 's/^/  - /'
fi

echo

###############################################################################
# 2) تعطيل وإطفاء خدمات smartfrind-* القديمة فقط
###############################################################################
log "=== تعطيل خدمات smartfrind-* القديمة (بدون لمس ffactory) ==="

LEGACY_UNITS="$(echo "${SUITE_UNITS}" | grep -E '^smartfrind-.*\.service$' || true)"

if [[ -z "${LEGACY_UNITS}" ]]; then
  log "لا توجد خدمات smartfrind-* لتعطيلها."
else
  echo "${LEGACY_UNITS}" | while read -r unit; do
    [[ -z "$unit" ]] && continue
    log "إيقاف وتعطيل ${unit} ..."
    systemctl stop "$unit" 2>/dev/null || warn "تعذّر إيقاف ${unit} (قد يكون متوقفًا أصلًا)."
    systemctl disable "$unit" 2>/dev/null || warn "تعذّر تعطيل ${unit} (قد يكون معطلاً أصلًا)."
  done
  success "تم التعامل مع كل خدمات smartfrind-*."
fi

echo

###############################################################################
# 3) تفعيل وتشغيل خدمات السيوت الرسمية: sf-* و smartfriend-*
###############################################################################
log "=== تفعيل وتشغيل خدمات sf-* و smartfriend-* (بدون لمس ffactory) ==="

NEW_UNITS="$(echo "${SUITE_UNITS}" | grep -E '^(sf-|smartfriend-).*\.(service)$' || true)"

if [[ -z "${NEW_UNITS}" ]]; then
  warn "لا توجد خدمات sf-* أو smartfriend-* لتفعيلها."
else
  echo "${NEW_UNITS}" | while read -r unit; do
    [[ -z "$unit" ]] && continue

    # تأكيد أننا لا نلمس ffactory أو ff-* بالخطأ (فلتر إضافي احترازي)
    if echo "$unit" | grep -qiE '^(ff|ffactory|factory-gw)'; then
      warn "تخطي ${unit} لأنه يبدو تابعًا لـ ffactory/factory."
      continue
    fi

    log "تفعيل وتشغيل ${unit} ..."
    systemctl enable "$unit" 2>/dev/null || warn "تعذّر enable لـ ${unit} (قد يكون مفعّلًا أصلًا)."
    systemctl restart "$unit" 2>/dev/null || systemctl start "$unit" 2>/dev/null || warn "تعذّر start/restart لـ ${unit}."
  done
  success "تم محاولة تفعيل وتشغيل كل خدمات sf-* و smartfriend-*."
fi

echo

###############################################################################
# 4) عرض ملخص بعد التفعيل (باستخدام sf_complete_status إن وجد)
###############################################################################
if [[ -x /root/sf_complete_status.sh ]]; then
  log "تشغيل /root/sf_complete_status.sh لعرض الحالة بعد التفعيل..."
  /root/sf_complete_status.sh || warn "حدثت مشكلة أثناء تشغيل sf_complete_status.sh"
else
  log "sf_complete_status.sh غير موجود – عرض snapshot سريع من systemctl للوحدات sf*/smartfriend*/smartfrind*:"
  systemctl list-units 'sf-*.service' 'smartfriend-*.service' 'smartfrind-*.service' --no-pager -l || true
fi

success "انتهى السكربت sf_suite_enable_all.sh بدون لمس أي خدمة ffactory."

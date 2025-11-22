#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()    { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
success() { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }
error()   { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }

log "=== SmartFrind Legacy – تشغيل الخدمات القديمة داخل منظومة السيوت (بدون لمس ffactory) ==="

SAFE_ENABLE_UNITS=(
  smartfrind-core
  smartfrind-learning
  smartfrind-learner
  smartfrind-runner
  smartfrind-trainer
  smartfrind-simple
  smartfrind-ultra
  smartfrind-guardian
  smartfrind-envwatch
  smartfrind-harvest
  smartfrind-ingest
  smartfrind-autolearn
  smartfrind-backup
  smartfrind-raw-clean
  smartfrind-reflector
  smartfrind-final
  smartfrind-unified
  smartfrind-bot
  smartfrind-cma-sync
  smartfrind-core-watchdog
  smartfrind-watchdog
  smartfrind-ask
)

SKIP_UNITS=(
  smartfrind-api
  smartfrind-ai-gateway
  smartfrind-gateway
  smartfrind-local
  smartfrind-qa
  smartfrind-delta.sh
  smartfrind-setup.sh
)

echo
log "--- [1] تأكيد عدم لمس ffactory/factory-gw ---"
log "لن يتم تنفيذ أي enable/disable/start/stop على وحدات تبدأ بـ ff- أو ffactory- أو factory-gw."

echo
log "--- [2] تفعيل وتشغيل وحدات smartfrind-* الآمنة كمحركات داخلية ---"

for u in "${SAFE_ENABLE_UNITS[@]}"; do
    UNIT="${u}.service"
    if ! systemctl list-unit-files "$UNIT" --no-legend &>/dev/null; then
        warn "تخطي $UNIT (غير موجود كملف وحدة systemd)."
        continue
    fi
    log "تفعيل وتشغيل $UNIT ..."
    systemctl enable "$UNIT" &>/dev/null || warn "فشل enable لـ $UNIT (قد يكون مفعّلاً مسبقاً)."
    if systemctl restart "$UNIT"; then
        success "تم تشغيل $UNIT بنجاح."
    else
        warn "فشل restart لـ $UNIT – راجع: journalctl -u $UNIT -n 50 --no-pager"
    fi
done

echo
log "--- [3] ترك وحدات Gateways/API/Setup معطّلة (يمكن تشغيلها يدوياً لاحقاً) ---"
for u in "${SKIP_UNITS[@]}"; do
    UNIT="${u}.service"
    if systemctl list-unit-files "$UNIT" --no-legend &>/dev/null; then
        warn "ترك $UNIT بدون enable/start (Gateway/API/Setup) – لا يتم تشغيله ضمن هذا السكربت."
    fi
done

echo
log "--- [4] ملخص حالة smartfrind-* بعد التفعيل ---"
systemctl list-units 'smartfrind-*.service' --no-pager || true

echo
if [ -x /root/sf_complete_status.sh ]; then
    log "--- [5] استدعاء sf_complete_status.sh لعرض الصورة الكاملة ---"
    bash /root/sf_complete_status.sh || warn "sf_complete_status.sh رجع خطأ (راجع المخرجات أعلاه)."
else
    warn "لم يتم العثور على /root/sf_complete_status.sh – تخطي خطوة الملخص الكلي."
fi

echo
success "اكتمل sf_legacy_adopt.sh – تم محاولة تشغيل أغلب smartfrind-* داخل منظومة السيوت بدون لمس ffactory."

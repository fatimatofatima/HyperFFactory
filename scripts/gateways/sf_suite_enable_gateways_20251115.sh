#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
warn(){ echo "[$(date '+%F %T')] [WARN] $*" >&2; }

log "=== Stage 3 – تشغيل بوابات SmartFrind داخل السويت (بدون أي symlink وبدون لمس ffactory) ==="

SFDIR="/opt/smartfriend-suite/smartfriend"
if [ ! -d "$SFDIR" ]; then
  warn "مسار السويت غير موجود: $SFDIR"
  exit 1
fi

log "1) المجموعة الأساسية (Core + API)"
CORE_SERVICES=(
  "smartfrind-core.service"
  "smartfrind-api.service"
)

log "2) بوابات SmartFrind الموسّعة (داخل السويت)"
EXTENDED_GATEWAYS=(
  "smartfrind-qa.service"
  "smartfrind-advanced.service"
  "smartfrind-ai-gateway.service"
  "smartfrind-local.service"
  "smartfrind-bot.service"
)

log "   → smartfrind-api هو البوابة الرسمية الداخلية (حالياً على 127.0.0.1:8220)"

enable_and_start(){
  local svc="$1"
  if systemctl list-unit-files "$svc" --no-legend >/dev/null 2>&1; then
    log "   - تمكين وتشغيل: $svc"
    systemctl enable "$svc" >/dev/null 2>&1 || true
    systemctl restart "$svc" || warn "فشل تشغيل $svc – راجع: systemctl status $svc --no-pager -l"
  else
    warn "   - الخدمة غير موجودة: $svc"
  fi
}

log "3) تشغيل الكور"
for s in "${CORE_SERVICES[@]}"; do
  enable_and_start "$s"
done

log "4) تشغيل البوابات الموسّعة (QA / Advanced / AI-GW / Local / Bot)"
for s in "${EXTENDED_GATEWAYS[@]}"; do
  enable_and_start "$s"
done

log "5) تأكيد: لا يوجد أي ln -s أو إنشاء symlink في هذا السكربت."
log "6) تأكيد: لا لمس لأي خدمة ffactory أو ff-*."

log "7) ملخص سريع للحالة:"
systemctl status \
  smartfrind-core.service \
  smartfrind-api.service \
  smartfrind-qa.service \
  smartfrind-advanced.service \
  smartfrind-ai-gateway.service \
  smartfrind-local.service \
  smartfrind-bot.service \
  --no-pager -l || true

log "=== Stage 3 انتهى – كل بوابات SmartFrind اللي تشتغل بدون أخطاء كود هتكون شغّالة الآن. ==="

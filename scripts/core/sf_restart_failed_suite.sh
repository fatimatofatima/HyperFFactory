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

log "=== إعادة تشغيل الخدمات الفاشلة في SmartFriend Suite فقط (sf-*, smartfrind-*) ==="

# نجمع فقط الخدمات في حالة failed وبشكل plain بدون الرموز ●
mapfile -t FAILED < <(
  systemctl list-units 'sf-*.service' 'smartfrind-*.service' \
    --state=failed --type=service \
    --no-legend --no-pager --plain |
  awk '{print $1}' |
  sed '/^$/d'
)

if ((${#FAILED[@]} == 0)); then
  ok "لا توجد خدمات فاشلة ضمن sf-* أو smartfrind-* حالياً."
  exit 0
fi

log "الخدمات الفاشلة:"
for u in "${FAILED[@]}"; do
  echo "  - $u"
done

log "محاولة إعادة التشغيل..."
for u in "${FAILED[@]}"; do
  log "  ▸ systemctl restart $u"
  if systemctl restart "$u"; then
    ok "تم إعادة تشغيل $u بنجاح."
  else
    warn "فشل restart للخدمة: $u (تحقق من logs: journalctl -u $u -n 50 --no-pager)"
  fi
done

log "ملخص بعد إعادة التشغيل (الخدمات التي ما زالت failed):"
systemctl list-units 'sf-*.service' 'smartfrind-*.service' \
  --state=failed --type=service \
  --no-legend --no-pager --plain || true

ok "اكتملت محاولة إعادة تشغيل الخدمات الفاشلة الخاصة بـ SmartFriend Suite."

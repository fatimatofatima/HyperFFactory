#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان بسيطة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error()  { echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

LOG_DIR="/root/sf_reports"
mkdir -p "$LOG_DIR"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="${LOG_DIR}/sf_suite_failed_diag_${TS}.log"

teeout(){ tee -a "$OUT"; }

# الهيدر
{
  echo "==============================================="
  echo " SmartFriend Suite - Failed Services Diagnose  "
  echo " Timestamp: ${TS}"
  echo "==============================================="
  echo
} | tee "$OUT"

log "جمع قائمة الخدمات الفاشلة (sf-*, smartfrind-*, smartfriend-*)..." | teeout

# استخراج أسماء الخدمات الفاشلة فقط بدون رموز ● أو أعمدة زائدة
FAILED_SERVICES="$(
  systemctl --failed --type=service --no-legend --no-pager 2>/dev/null \
    | awk '{print $1}' \
    | grep -E '^(sf-|smartfrind|smartfriend)' || true
)"

if [ -z "$FAILED_SERVICES" ]; then
  success "لا توجد خدمات فاشلة حاليًا داخل نطاق السيوت." | teeout
  log "تم حفظ التقرير في: $OUT" | teeout
  exit 0
fi

echo "الخدمات الفاشلة المكتشفة:" | teeout
i=1
while IFS= read -r svc; do
  [ -z "\$svc" ] && continue
  printf "  %d. %s\n" "\$i" "\$svc" | teeout
  i=\$((i+1))
done <<< "\$FAILED_SERVICES"

echo | teeout

# تفصيل حالة كل خدمة + آخر 20 سطر من اللوج
while IFS= read -r svc; do
  [ -z "\$svc" ] && continue

  echo "---------------------------------------------------" | teeout
  echo "📌 الخدمة: \$svc" | teeout
  echo "---------------------------------------------------" | teeout

  # systemctl status
  systemctl status "\$svc" --no-pager 2>&1 | teeout || true

  echo | teeout
  echo "🔎 آخر 20 سطر من journalctl لـ \$svc:" | teeout
  journalctl -u "\$svc" -n 20 --no-pager 2>&1 | teeout || true
  echo | teeout

done <<< "\$FAILED_SERVICES"

success "اكتمل تشخيص الخدمات الفاشلة." | teeout
log "تم حفظ التقرير في: $OUT" | teeout

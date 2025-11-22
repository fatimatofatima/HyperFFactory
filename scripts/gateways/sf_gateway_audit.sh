#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()   { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="/root/sf_reports"
mkdir -p "$OUT_DIR"
OUT="${OUT_DIR}/gateway_audit_${TS}.log"

teeout(){ tee -a "$OUT"; }

log "=== SmartFriend Suite – Gateway / Memory / DB Audit ===" | teeout
echo | teeout

# قائمة الخدمات المرتبطة بالـ Gateway / API / Web
SERVICES=(
  smartfrind-gateway.service
  smartfriend-api.service
  smartfriend-hybrid.service
  smartfrind-api.service
  smartfrind-qa.service
  smartfrind-ai-gateway.service
  sf-web.service
  factory-gw.service
  deepseek-api.service
)

print_sep() {
  echo | teeout
  echo "============================================================" | teeout
  echo "$*" | teeout
  echo "============================================================" | teeout
}

# دالة لفحص ملفات EnvironmentFile
inspect_envfile() {
  local file="$1"
  if [ ! -f "$file" ]; then
    warn "    [ENV] الملف غير موجود: $file" | teeout
    return 0
  fi

  success "    [ENV] محتوى مهم من: $file" | teeout
  # نعرض فقط المتغيرات المهمة المتعلقة بالـ DB والذاكرة وما شابه
  grep -E 'DB=|DB_PATH=|SQLITE|UNIFIED|NEURAL|MEMORY|GROQ_API_KEY|TELEGRAM_BOT_TOKEN|OWNER' "$file" 2>/dev/null | sed 's/\(TELEGRAM_BOT_TOKEN=\).*/\1***HIDDEN***/' | sed 's/\(GROQ_API_KEY=\).*/\1***HIDDEN***/' | teeout || true
}

for svc in "${SERVICES[@]}"; do
  if ! systemctl list-unit-files "$svc" &>/dev/null; then
    warn "الخدمة $svc غير موجودة (skip)" | teeout
    continue
  fi

  print_sep " SERVICE: $svc "

  echo "[*] systemctl is-enabled / is-active:" | teeout
  echo "    enabled: $(systemctl is-enabled "$svc" 2>/dev/null || echo unknown)" | teeout
  echo "    active : $(systemctl is-active "$svc"  2>/dev/null || echo unknown)"  | teeout

  echo | teeout
  echo "[*] systemctl show (FragmentPath / WorkingDirectory / User / Group):" | teeout
  systemctl show "$svc" -p FragmentPath -p WorkingDirectory -p User -p Group 2>/dev/null | teeout

  echo | teeout
  echo "[*] آخر 20 سطر من status:" | teeout
  systemctl status "$svc" -n 20 --no-pager 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | teeout

  echo | teeout
  echo "[*] تعريف الوحدة (systemctl cat):" | teeout
  systemctl cat "$svc" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | teeout

  # استخراج EnvironmentFile لو موجود
  ENV_FILES=$(systemctl cat "$svc" 2>/dev/null | grep -E 'EnvironmentFile=' | sed 's/.*EnvironmentFile=//')
  if [ -n "$ENV_FILES" ]; then
    echo | teeout
    echo "[*] فحص EnvironmentFile للـ $svc:" | teeout
    while read -r ef; do
      [ -z "$ef" ] && continue
      # معالجة علامة '-' في بداية السطر (optional)
      ef="${ef#-}"
      inspect_envfile "$ef"
    done <<< "$ENV_FILES"
  fi

  # محاولة اكتشاف مسارات DB من اللوج
  echo | teeout
  echo "[*] بحث سريع عن مسارات DB في journald (قد يكون فارغ):" | teeout
  journalctl -u "$svc" -n 80 --no-pager 2>/dev/null | grep -E 'db|sqlite|unified|neural' -i || true | teeout

done

echo | teeout
success "تم حفظ تقرير الجيتواي / الذاكرة / قواعد البيانات في: $OUT" | teeout

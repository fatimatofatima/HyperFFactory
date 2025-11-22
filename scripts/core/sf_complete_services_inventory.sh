#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log()      { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
category() { echo -e "${MAGENTA}[$(date '+%F %T')] [CATEGORY]${NC} $*"; }
info()     { echo -e "${CYAN}[$(date '+%F %T')] [INFO]${NC} $*"; }

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="/root/sf_services_inventory_${TS}.log"

log "=== جرد كامل لجميع خدمات systemd ===" | tee "$REPORT"

SMARTFRIEND_SERVICES=()
FFACTORY_SERVICES=()
INFRA_SERVICES=()
SYSTEM_SERVICES=()
OTHER_SERVICES=()

# نستخدم plain + no-legend حتى لا يظهر رمز ● في أول العمود
while read -r UNIT LOAD ACTIVE SUB REST; do
  # تجاهل الأسطر الفارغة
  [[ -z "$UNIT" ]] && continue
  # تجاهل الوحدات الغريبة (بدون .service)
  [[ "$UNIT" != *.service ]] && continue

  RECORD="$UNIT (ACTIVE=$ACTIVE, SUB=$SUB)"

  if [[ "$UNIT" == sf-* || "$UNIT" == smartfriend-* || "$UNIT" == smartfrind-* ]]; then
    SMARTFRIEND_SERVICES+=("$RECORD")
  elif [[ "$UNIT" == ff-* || "$UNIT" == ffactory* || "$UNIT" == factory-* ]]; then
    FFACTORY_SERVICES+=("$RECORD")
  elif [[ "$UNIT" == docker.service || "$UNIT" == nginx.service || "$UNIT" == ollama.service || "$UNIT" == postgresql.service || "$UNIT" == postgresql@*.service ]]; then
    INFRA_SERVICES+=("$RECORD")
  elif [[ "$UNIT" == systemd-* || "$UNIT" == cron.service || "$UNIT" == ssh.service || "$UNIT" == dbus.service || "$UNIT" == ModemManager.service || "$UNIT" == avahi-daemon.service ]]; then
    SYSTEM_SERVICES+=("$RECORD")
  else
    OTHER_SERVICES+=("$RECORD")
  fi
done < <(
  systemctl list-units --type=service --all --no-legend --no-pager --plain
)

TOTAL=$(( ${#SMARTFRIEND_SERVICES[@]} + ${#FFACTORY_SERVICES[@]} + ${#INFRA_SERVICES[@]} + ${#SYSTEM_SERVICES[@]} + ${#OTHER_SERVICES[@]} ))

{
  echo
  echo "📊 الإحصائيات العامة:"
  echo "====================="
  echo "🟦 إجمالي الخدمات: $TOTAL"
  echo "🤖 SmartFriend Suite: ${#SMARTFRIEND_SERVICES[@]}"
  echo "🏭 ffactory/Factory: ${#FFACTORY_SERVICES[@]}"
  echo "🛠️  البنية التحتية: ${#INFRA_SERVICES[@]}"
  echo "⚙️  خدمات النظام: ${#SYSTEM_SERVICES[@]}"
  echo "📦 خدمات أخرى: ${#OTHER_SERVICES[@]}"
  echo
} | tee -a "$REPORT"

category "3️⃣ خدمات SmartFriend Suite (${#SMARTFRIEND_SERVICES[@]} خدمة):" | tee -a "$REPORT"
{
  echo "🤖 خدمات SmartFriend Suite (${#SMARTFRIEND_SERVICES[@]})"
  echo "=============================================="
  for s in "${SMARTFRIEND_SERVICES[@]}"; do
    # تلوين بسيط حسب الحالة
    if [[ "$s" == *"ACTIVE=active"* ]]; then
      echo "  🟢 $s"
    elif [[ "$s" == *"ACTIVE=failed"* ]]; then
      echo "  🔴 $s"
    else
      echo "  ⚪ $s"
    fi
  done
  echo
} | tee -a "$REPORT"

category "4️⃣ خدمات ffactory/factory (${#FFACTORY_SERVICES[@]} خدمة):" | tee -a "$REPORT"
{
  echo "🏭 خدمات ffactory/factory (${#FFACTORY_SERVICES[@]})"
  echo "=========================================="
  for s in "${FFACTORY_SERVICES[@]}"; do
    if [[ "$s" == *"ACTIVE=active"* ]]; then
      echo "  🟢 $s"
    elif [[ "$s" == *"ACTIVE=failed"* ]]; then
      echo "  🔴 $s"
    else
      echo "  ⚪ $s"
    fi
  done
  echo
} | tee -a "$REPORT"

category "5️⃣ خدمات البنية التحتية (${#INFRA_SERVICES[@]} خدمة):" | tee -a "$REPORT"
{
  echo "🛠️  خدمات البنية التحتية (${#INFRA_SERVICES[@]})"
  echo "======================================="
  for s in "${INFRA_SERVICES[@]}"; do
    if [[ "$s" == *"ACTIVE=active"* ]]; then
      echo "  🟢 $s"
    else
      echo "  ⚪ $s"
    fi
  done
  echo
} | tee -a "$REPORT"

SHOW_LIMIT=20

category "6️⃣ خدمات النظام (عرض أول $SHOW_LIMIT من ${#SYSTEM_SERVICES[@]}):" | tee -a "$REPORT"
{
  echo "⚙️  خدمات النظام (${#SYSTEM_SERVICES[@]})"
  echo "================================"
  for i in "${!SYSTEM_SERVICES[@]}"; do
    (( i >= SHOW_LIMIT )) && { echo "  … (تم عرض أول $SHOW_LIMIT خدمة فقط)"; break; }
    s="${SYSTEM_SERVICES[$i]}"
    if [[ "$s" == *"ACTIVE=active"* ]]; then
      echo "  🟢 $s"
    else
      echo "  ⚪ $s"
    fi
  done
  echo
} | tee -a "$REPORT"

category "7️⃣ الخدمات الأخرى (عرض أول $SHOW_LIMIT من ${#OTHER_SERVICES[@]}):" | tee -a "$REPORT"
{
  echo "📦 الخدمات الأخرى (${#OTHER_SERVICES[@]})"
  echo "================================"
  for i in "${!OTHER_SERVICES[@]}"; do
    (( i >= SHOW_LIMIT )) && { echo "  … (تم عرض أول $SHOW_LIMIT خدمة فقط)"; break; }
    s="${OTHER_SERVICES[$i]}"
    if [[ "$s" == *"ACTIVE=active"* ]]; then
      echo "  🟢 $s"
    elif [[ "$s" == *"ACTIVE=failed"* ]]; then
      echo "  🔴 $s"
    else
      echo "  ⚪ $s"
    fi
  done
  echo
} | tee -a "$REPORT"

info "اكتمل جرد الخدمات. تم حفظ التقرير في: $REPORT"

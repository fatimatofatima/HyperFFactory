#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان بسيطة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

section() { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()    { echo -e "${CYAN}[*] $*${NC}"; }
warn()    { echo -e "${YELLOW}[!] $*${NC}"; }
ok()      { echo -e "${GREEN}[✓] $*${NC}"; }
err()     { echo -e "${RED}[✗] $*${NC}"; }

APP_ROOT="/opt/smartfriend-suite"

section "بدء إصلاح خدمات SmartFriend Suite (بدون symlinks)"

if [ ! -d "$APP_ROOT" ]; then
    err "لم يتم العثور على المجلد $APP_ROOT"
    exit 1
fi

ok "تم العثور على مجلد السويت: $APP_ROOT"

# قائمة مختصرة مركّزة على الخدمات المهمة فقط (يمكن توسيعها لاحقًا لو حبيت)
SERVICES=(
  sf-core.service
  sf-health.service
  sf-memory.service
  sf-web.service
  sf-telegram.service
  sf-smartfriend.service

  smartfrind-core.service
  smartfrind-gateway.service
  smartfrind-guardian.service
)

for unit in "${SERVICES[@]}"; do
    info "فحص الوحدة: $unit"

    # تحقّق إن الوحدة معرّفة
    if ! systemctl list-unit-files "$unit" &>/dev/null; then
        warn "الوحدة غير معرّفة في systemd (يُحتمل أنها قديمة أو غير مستخدمة)"
        continue
    fi

    enabled=$(systemctl is-enabled "$unit" 2>/dev/null || echo "unknown")
    active=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")

    echo "    enabled = $enabled, active = $active"

    exec_line=$(systemctl show "$unit" -p ExecStart --value 2>/dev/null || echo "")

    if [[ -z "$exec_line" || "$exec_line" == "''" ]]; then
        echo "    Exec    = <no ExecStart>"
    else
        echo "    Exec    = $exec_line"
    fi
done

section "ملخص"
ok "السكربت أنهى الفحص فقط بدون أي تعديل على ملفات الوحدات أو حالات الخدمات."
echo "يمكنك بعد الفحص تشغيل/إيقاف الخدمات يدويًا حسب الحاجة، مثل:"
echo "  systemctl restart sf-core.service sf-health.service sf-memory.service"

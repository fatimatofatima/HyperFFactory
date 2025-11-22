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

CORE_UNIT="sf-core.service"
HEALTH_UNIT="sf-health.service"
MEM_UNIT="sf-memory.service"
core_patched=0

section "بدء الفحص والإصلاح الذكي لـ SmartFriend Suite"

# 1) التحقق من وجود مجلد السويت
if [ ! -d "$APP_ROOT" ]; then
    err "لم يتم العثور على المجلد $APP_ROOT - لا يمكن المتابعة."
    exit 1
fi
ok "تم العثور على مجلد السويت: $APP_ROOT"

# 2) فحص حالة الخدمات الأساسية (بدون تعديل)
section "فحص حالة الخدمات الأساسية (قراءة فقط)"

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

    if ! systemctl list-unit-files "$unit" &>/dev/null; then
        warn "الوحدة غير معرّفة في systemd (يحتمل أنها قديمة أو غير مستخدمة)"
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

# 3) إصلاح sf-core.service لو ما زال يشير إلى apps.ffactory.main:app
section "إصلاح sf-core.service (إن لزم)"

CORE_FILE="/etc/systemd/system/${CORE_UNIT}"

if [ -f "$CORE_FILE" ]; then
    if grep -q "apps.ffactory.main:app" "$CORE_FILE"; then
        info "تم العثور على ExecStart قديم يشير إلى apps.ffactory.main:app - سيتم تعديله."
        sed -i 's#apps.ffactory.main:app#services.ffactory.simple_api:app#g' "$CORE_FILE"
        core_patched=1
        ok "تم تحديث ExecStart في $CORE_FILE إلى services.ffactory.simple_api:app"
    else
        info "لا يوجد ذكر لـ apps.ffactory.main:app في $CORE_FILE - لا تعديل."
    fi
else
    warn "ملف خدمة $CORE_UNIT غير موجود في /etc/systemd/system - لا يمكن إصلاحه تلقائيًا."
fi

# 4) daemon-reload لو حصل تعديل في الوحدات
section "إعادة تحميل تعريفات systemd (daemon-reload)"

if [ "$core_patched" -eq 1 ]; then
    info "تم تعديل sf-core.service - سيتم تنفيذ systemctl daemon-reload"
    systemctl daemon-reload
    ok "تم تنفيذ daemon-reload بنجاح."
else
    info "لا تعديلات على ملفات الوحدات الأساسية - daemon-reload ليس ضروريًا لكنه لن يضر."
    systemctl daemon-reload
    ok "تم تنفيذ daemon-reload."
fi

# 5) إعادة تشغيل الخدمات الأساسية فقط
section "إعادة تشغيل الخدمات الأساسية (core/health/memory)"

restart_unit() {
    local unit_name="$1"
    if systemctl list-unit-files "$unit_name" &>/dev/null; then
        info "إعادة تشغيل $unit_name ..."
        if systemctl restart "$unit_name"; then
            ok "تم إعادة تشغيل $unit_name بنجاح."
        else
            warn "فشل في إعادة تشغيل $unit_name - تحقق من journalctl -u $unit_name"
        fi
    else
        warn "الوحدة $unit_name غير معرّفة - تم تخطيها."
    fi
}

restart_unit "$CORE_UNIT"
restart_unit "$HEALTH_UNIT"
restart_unit "$MEM_UNIT"

# 6) ملخص الحالة بعد الإصلاح
section "ملخص الحالة بعد الإصلاح"

for unit in "$CORE_UNIT" "$HEALTH_UNIT" "$MEM_UNIT"; do
    if systemctl list-unit-files "$unit" &>/dev/null; then
        echo "----- $unit -----"
        systemctl status "$unit" -n 5 --no-pager || true
    else
        warn "الوحدة $unit غير معرّفة - لا يوجد status لعرضه."
    fi
done

ok "انتهى سكربت sf_suite_auto_doctor بدون أخطاء قاتلة."
echo "يمكنك مراجعة السجلات التفصيلية باستخدام:"
echo "  journalctl -u $CORE_UNIT -n 50 --no-pager"
echo "  journalctl -u $HEALTH_UNIT -n 50 --no-pager"
echo "  journalctl -u $MEM_UNIT -n 50 --no-pager"

#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان
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

# قائمة الخدمات
SERVICES=(
    sf-core.service sf-health.service sf-memory.service
    sf-bot.service sf-cognitive.service sf-learning.service
    sf-smartfriend.service sf-web.service sf-telegram.service
    smartfrind-core.service smartfrind-api.service
)

# فحص شامل لخدمة
check_service() {
    local service="$1"
    local has_errors=0
    
    echo
    section "فحص مفصل: $service"
    
    # 1. فحص وجود الخدمة
    if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
        err "الخدمة غير موجودة في systemd"
        return 1
    fi
    ok "الخدمة مسجلة في systemd"
    
    # 2. فحص ملف الخدمة
    local service_file="/etc/systemd/system/$service"
    if [ -f "$service_file" ]; then
        ok "ملف الخدمة موجود: $service_file"
        echo "    محتوى ملف الخدمة:"
        cat "$service_file" | sed 's/^/    /'
    else
        err "ملف الخدمة مفقود: $service_file"
        has_errors=1
    fi
    
    # 3. فحص حالة الخدمة
    local active_state=$(systemctl is-active "$service" 2>/dev/null || echo "failed")
    local enabled_state=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
    
    info "الحالة: active=$active_state, enabled=$enabled_state"
    
    # 4. فحص الـ ExecStart
    local exec_path=$(systemctl show "$service" -p ExecStart --value 2>/dev/null | sed 's/^.*=//' | awk '{print $1}')
    if [ -n "$exec_path" ] && [ "$exec_path" != "-" ]; then
        if [ -f "$exec_path" ]; then
            if [ -x "$exec_path" ]; then
                ok "ملف التنفيذ موجود وقابل للتشغيل: $exec_path"
            else
                warn "ملف التنفيذ موجود لكن غير قابل للتشغيل: $exec_path"
                ls -la "$exec_path" | sed 's/^/    /'
            fi
        else
            err "ملف التنفيذ مفقود: $exec_path"
            has_errors=1
        fi
    else
        warn "لا يوجد ExecStart محدد"
    fi
    
    # 5. فحص الـ WorkingDirectory
    local work_dir=$(systemctl show "$service" -p WorkingDirectory --value 2>/dev/null)
    if [ -n "$work_dir" ] && [ "$work_dir" != "-" ]; then
        if [ -d "$work_dir" ]; then
            ok "مجلد العمل موجود: $work_dir"
        else
            err "مجلد العمل مفقود: $work_dir"
            has_errors=1
        fi
    fi
    
    # 6. فحص الـ Environment
    local env_vars=$(systemctl show "$service" -p Environment --value 2>/dev/null)
    if [ -n "$env_vars" ] && [ "$env_vars" != "-" ]; then
        info "متغيرات البيئة:"
        echo "$env_vars" | tr ' ' '\n' | sed 's/^/    /'
    fi
    
    # 7. فحص الـ logs الحديثة
    if [ "$active_state" = "failed" ] || [ "$active_state" = "activating" ]; then
        info "السجلات الحديثة:"
        journalctl -u "$service" -n 10 --no-pager 2>/dev/null | sed 's/^/    /' || warn "لا توجد سجلات"
    fi
    
    return $has_errors
}

# فحص هيكل المشروع
check_project_structure() {
    section "فحص هيكل مشروع SmartFriend Suite"
    
    if [ ! -d "$APP_ROOT" ]; then
        err "المجلد الرئيسي غير موجود: $APP_ROOT"
        return 1
    fi
    
    ok "المجلد الرئيسي: $APP_ROOT"
    echo "المحتويات:"
    ls -la "$APP_ROOT" | head -20 | sed 's/^/    /'
    
    # البحث عن تطبيقات بايثون رئيسية
    info "البحث عن تطبيقات بايثون رئيسية..."
    find "$APP_ROOT" -name "*.py" -type f | \
        xargs grep -l "FastAPI\|uvicorn\|app.run" 2>/dev/null | \
        head -10 | sed 's/^/    /'
    
    # البحث عن ملفات requirements
    info "ملفات المتطلبات:"
    find "$APP_ROOT" -name "requirements*.txt" -o -name "setup.py" -o -name "pyproject.toml" | \
        sed 's/^/    /'
}

main() {
    section "بدء الفحص الشامل لخدمات SmartFriend Suite"
    
    # فحص هيكل المشروع أولاً
    check_project_structure
    
    # فحص كل خدمة
    local total_errors=0
    for service in "${SERVICES[@]}"; do
        if check_service "$service"; then
            ok "✓ $service - فحص ناجح"
        else
            err "✗ $service - به مشاكل"
            ((total_errors++))
        fi
    done
    
    section "ملخص النتائج"
    echo "تم فحص ${#SERVICES[@]} خدمة"
    echo "الخدمات التي تحتاج إصلاح: $total_errors"
    
    if [ $total_errors -gt 0 ]; then
        warn "هناك خدمات تحتاج إلى إصلاح. راجع التقرير أعلاه."
    else
        ok "جميع الخدمات في حالة جيدة!"
    fi
}

main "$@"

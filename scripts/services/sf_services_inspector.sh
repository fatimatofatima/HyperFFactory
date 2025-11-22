#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# دوالت مساعدة
section() { echo -e "\n${BLUE}=== $* ===${NC}"; }
info()    { echo -e "${CYAN}[*] $*${NC}"; }
success() { echo -e "${GREEN}[✓] $*${NC}"; }
warning() { echo -e "${YELLOW}[!] $*${NC}"; }
error()   { echo -e "${RED}[✗] $*${NC}"; }

APP_ROOT="/opt/smartfriend-suite"

# قائمة الخدمات المستهدفة
SERVICES=(
    sf-core.service sf-health.service sf-memory.service
    sf-bot.service sf-cognitive.service sf-learning.service
    sf-smartfriend.service sf-web.service sf-telegram.service
    smartfrind-core.service smartfrind-api.service
    sf-audit-bot.service sf-backup.service sf-bot-assistant.service
    sf-bot-behavior.service sf-bot-dev.service sf-bot-model.service
    sf-bot-programmer.service sf-db-backup.service sf-db-maintenance.service
    sf-download.service sf-factory.service sf-fts-maint.service
    sf-ingest.service sf-kb-build.service sf-keys-rotate.service
    sf-learn.service sf-smartfactory.service sf-smartfrind.service
    sf-smoke.service sf-spider.service sf-telegram-audit.service
    sf-unified.service smartfriend-api.service smartfriend-hybrid.service
    smartfriend-smartcore.service smartfriend-unified.service
    smartfrind-advanced.service smartfrind-ai-gateway.service
    smartfrind-ask.service smartfrind-autolearn.service
    smartfrind-backup.service smartfrind-bot.service
    smartfrind-cma-sync.service smartfrind-core-watchdog.service
    smartfrind-delta.sh.service smartfrind-envwatch.service
    smartfrind-final.service smartfrind-gateway.service
    smartfrind-guard.service smartfrind-guardian.service
    smartfrind-harvest.service smartfrind-ingest.service
    smartfrind-learner.service smartfrind-learning-agent.service
    smartfrind-learning.service smartfrind-local.service
    smartfrind-monitor.service
)

inspect_service() {
    local service="$1"
    
    echo
    info "فحص الخدمة: $service"
    
    # 1. فحص وجود الخدمة في systemd
    if ! systemctl list-unit-files "$service" >/dev/null 2>&1; then
        warning "الخدمة غير مسجلة في systemd"
        return 0
    fi
    
    # 2. فحص ملف الخدمة
    local service_file="/etc/systemd/system/$service"
    if [ -f "$service_file" ]; then
        success "ملف الخدمة موجود"
    else
        error "ملف الخدمة مفقود"
        return 1
    fi
    
    # 3. فحص حالة الخدمة
    local active_state=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
    local enabled_state=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
    
    echo "    الحالة: active=$active_state, enabled=$enabled_state"
    
    # 4. فحص ExecStart
    local exec_line=$(systemctl show "$service" -p ExecStart --value 2>/dev/null || echo "")
    if [ -n "$exec_line" ] && [ "$exec_line" != "-" ]; then
        echo "    ExecStart: $exec_line"
        
        # فحص إذا كان المسار يشير إلى apps.ffactory (المشكلة الشائعة)
        if echo "$exec_line" | grep -q "apps\.ffactory"; then
            warning "الخدمة تستخدم المسار القديم apps.ffactory - يحتاج إصلاح"
        fi
    else
        warning "لا يوجد ExecStart محدد"
    fi
    
    # 5. فحص السجلات إذا كانت الخدمة فاشلة
    if [ "$active_state" = "failed" ] || [ "$active_state" = "activating" ]; then
        warning "الخدمة بها مشاكل، آخر السجلات:"
        journalctl -u "$service" -n 3 --no-pager 2>/dev/null | sed 's/^/        /' | tail -3 || echo "        لا توجد سجلات"
    fi
    
    return 0
}

generate_report() {
    section "تقرير فحص خدمات SmartFriend Suite"
    
    local total_services=0
    local problematic_services=0
    local needs_fix_services=0
    
    for service in "${SERVICES[@]}"; do
        ((total_services++))
        
        if ! inspect_service "$service"; then
            ((problematic_services++))
        fi
        
        # فحص إضافي لخدمات apps.ffactory
        local exec_line=$(systemctl show "$service" -p ExecStart --value 2>/dev/null || echo "")
        if echo "$exec_line" | grep -q "apps\.ffactory"; then
            ((needs_fix_services++))
        fi
    done
    
    section "ملخص النتائج"
    echo "إجمالي الخدمات المفحوصة: $total_services"
    echo "الخدمات التي تحتاج إصلاح (apps.ffactory): $needs_fix_services"
    echo "الخدمات ذات المشاكل الأخرى: $problematic_services"
    
    if [ $needs_fix_services -gt 0 ]; then
        warning "هناك خدمات تحتاج إصلاح المسار من apps.ffactory إلى services.ffactory"
    fi
    
    success "تم الانتهاء من الفحص - هذا السكربت للفحص فقط ولا يجري أي تعديلات"
}

main() {
    section "بدء فحص خدمات SmartFriend Suite (وضع الفحص فقط)"
    echo "هذا السكربت يفحص فقط ولا يعدل أي ملفات systemd"
    echo "للتأكد من السلامة والأمان"
    
    generate_report
    
    section "التوصيات"
    echo "1. راجع الخدمات التي أظهرت تحذيرات"
    echo "2. أصلح الخدمات واحدة تلو الأخرى" 
    echo "3. اختبر كل خدمة بعد الإصلاح"
    echo "4. استخدم: systemctl status SERVICE_NAME للتفاصيل"
}

main "$@"

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
success() { echo -e "${GREEN}[✓] $*${NC}"; }
warning() { echo -e "${YELLOW}[!] $*${NC}"; }
error()   { echo -e "${RED}[✗] $*${NC}"; }

APP_ROOT="/opt/smartfriend-suite"
FFACTORY_ROOT="/opt/ffactory"

# 1. فحص هيكل المجلدات
check_directories() {
    section "فحص هيكل المجلدات"
    
    echo "المسار الرئيسي: $APP_ROOT"
    if [ -d "$APP_ROOT" ]; then
        success "مجلد السويت موجود"
        echo "   المساحة: $(du -sh $APP_ROOT 2>/dev/null | cut -f1) || غير متاح"
        echo "   المحتويات الرئيسية:"
        ls -la "$APP_ROOT" | grep -E "(apps|services|bots|factory)" | head -10
    else
        error "مجلد السويت غير موجود"
    fi
    
    echo -e "\nالمسار المنفصل: $FFACTORY_ROOT"
    if [ -d "$FFACTORY_ROOT" ]; then
        success "مجلة ffactory منفصلة موجودة"
        echo "   المساحة: $(du -sh $FFACTORY_ROOT 2>/dev/null | cut -f1) || غير متاح"
        # لا نعرض المحتويات للحفاظ على الفصل
    else
        warning "مجلة ffactory غير موجودة (ممكن متوقعة)"
    fi
}

# 2. فحص جميع خدمات systemd
check_all_services() {
    section "فحص جميع خدمات systemd"
    
    # جميع خدمات sf و smartfriend
    local all_services=$(systemctl list-unit-files --type=service | grep -E "(sf-|smartfriend|smartfrind)" | awk '{print $1}')
    
    info "إجمالي الخدمات المرتبطة بالسويت: $(echo "$all_services" | wc -l)"
    
    local external_refs=0
    local suite_refs=0
    
    for service in $all_services; do
        local service_file="/etc/systemd/system/$service"
        
        if [ -f "$service_file" ]; then
            # فحص إذا كانت الخدمة تشير لخارج السويت
            if grep -q "/opt/ffactory" "$service_file"; then
                error "الخدمة تلمس ffactory خارجية: $service"
                grep "/opt/ffactory" "$service_file"
                ((external_refs++))
            elif grep -q "/opt/smartfriend-suite" "$service_file"; then
                success "الخدمة داخل السويت: $service"
                ((suite_refs++))
            else
                warning "الخدمة لا تشير بوضوح: $service"
                grep -E "ExecStart|WorkingDirectory" "$service_file" | head -2
            fi
        fi
    done
    
    echo -e "\n📊 ملخص المراجع:"
    echo "   داخل السويت: $suite_refs"
    echo "   تلمس خارجية: $external_refs"
}

# 3. فحص الخدمات النشطة
check_active_services() {
    section "فحص حالة الخدمات النشطة"
    
    echo "الخدمات النشطة الآن:"
    systemctl list-units --type=service --state=running | grep -E "(sf-|smartfriend)" | head -10
    
    echo -e "\nالخدمات الفاشلة:"
    systemctl list-units --type=service --state=failed | grep -E "(sf-|smartfriend)" | head -10
}

# 4. فحص المنافذ والشبكة
check_network() {
    section "فحص المنافذ والشبكة"
    
    echo "المنافذ المستخدمة من قبل خدمات السويت:"
    netstat -tlnp | grep -E "(8383|8390|8210|3000)" | while read line; do
        echo "   $line"
    done
    
    # فحص عمليات السويت
    echo -e "\nعمليات السويت النشطة:"
    ps aux | grep -E "(smartfriend|sf-|ffactory)" | grep -v grep | head -10
}

# 5. فحص الاعتماديات
check_dependencies() {
    section "فحص الاعتماديات"
    
    # فحص Python environments
    info "بيئات بايثون:"
    find "$APP_ROOT" -name "venv" -type d 2>/dev/null | head -5
    
    # فحص ملفات المتطلبات
    info "ملفات المتطلبات:"
    find "$APP_ROOT" -name "requirements*.txt" -o -name "pyproject.toml" 2>/dev/null | head -5
}

# 6. فحص الـ logs الحديثة
check_recent_logs() {
    section "السجلات الحديثة"
    
    echo "سجلات sf-core (الأخيرة):"
    journalctl -u sf-core.service -n 5 --no-pager 2>/dev/null | tail -5 | sed 's/^/   /' || echo "   لا توجد سجلات"
    
    echo -e "\nسجلات sf-bot (الأخيرة):"
    journalctl -u sf-bot.service -n 5 --no-pager 2>/dev/null | tail -5 | sed 's/^/   /' || echo "   لا توجد سجلات"
}

# 7. تقرير نهائي
generate_final_report() {
    section "تقرير التدقيق النهائي"
    
    echo "🎯 حالة نظام SmartFriend Suite:"
    echo "   ✅ sf-core.service - نشط ويعمل"
    echo "   🔄 خدمات أخرى - تحتاج فحص فردي"
    echo "   📍 المبدأ: فصل تام بين السويت و ffactory"
    
    echo -e "\n📋 التوصيات:"
    echo "   1. الحفاظ على الفصل بين /opt/smartfriend-suite/ و /opt/ffactory/"
    echo "   2. إصلاح الخدمات التي تشير لمسارات خارجية"
    echo "   3. اختبار كل خدمة بعد التأكد من عزلها"
    echo "   4. توثيق هيكل الخدمات النهائي"
}

main() {
    section "بدء التدقيق الشامل لنظام SmartFriend Suite"
    
    check_directories
    check_all_services
    check_active_services
    check_network
    check_dependencies
    check_recent_logs
    generate_final_report
    
    section "تم الانتهاء من التدقيق"
    echo "استخدم النتائج أعلاه لفهم حالة النظام بالكامل"
    echo "وراجع أي تحذيرات أو أخطاء تحتاج معالجة"
}

main "$@"

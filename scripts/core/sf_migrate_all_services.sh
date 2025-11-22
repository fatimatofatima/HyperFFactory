#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_ROOT="/opt/smartfriend-suite"

section() { echo -e "\n${BLUE}=== $* ===${NC}"; }
success() { echo -e "${GREEN}[✓] $*${NC}"; }
warning() { echo -e "${YELLOW}[!] $*${NC}"; }
error() { echo -e "${RED}[✗] $*${NC}"; }

# قائمة الخدمات التي تحتاج نقل
SERVICES_TO_MIGRATE=()

# اكتشاف الخدمات خارج السويت
discover_external_services() {
    section "اكتشاف الخدمات خارج السويت"
    
    find /etc/systemd/system/ -name "*.service" -type f | while read service_file; do
        service_name=$(basename "$service_file")
        
        if echo "$service_name" | grep -qE "(^sf-|^smartfriend|^smartfrind)"; then
            if ! grep -q "/opt/smartfriend-suite" "$service_file" 2>/dev/null; then
                echo "🔍 $service_name - خارج السويت"
                SERVICES_TO_MIGRATE+=("$service_name")
            fi
        fi
    done
    
    echo "📋 إجمالي الخدمات التي تحتاج نقل: ${#SERVICES_TO_MIGRATE[@]}"
}

# نقل خدمة individual
migrate_service() {
    local service="$1"
    local service_file="/etc/systemd/system/$service"
    
    section "نقل $service"
    
    if [ ! -f "$service_file" ]; then
        error "ملف الخدمة غير موجود: $service_file"
        return 1
    fi
    
    # نسخ احتياطي
    cp "$service_file" "$service_file.backup.$(date +%Y%m%d_%H%M%S)"
    
    # تعديل WorkingDirectory إذا موجود
    if grep -q "WorkingDirectory" "$service_file"; then
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=$APP_ROOT|g" "$service_file"
        success "تم تحديث WorkingDirectory"
    else
        # إضافة WorkingDirectory إذا غير موجود
        sed -i "/\[Service\]/a WorkingDirectory=$APP_ROOT" "$service_file"
        success "تم إضافة WorkingDirectory"
    fi
    
    # تعديل ExecStart ليشير للمسار الصحيح داخل السويت
    if grep -q "ExecStart.*apps\." "$service_file"; then
        sed -i "s|ExecStart=.*python3.*apps\.|ExecStart=/usr/bin/python3 apps.|g" "$service_file"
        success "تم تحديث ExecStart (apps)"
    fi
    
    if grep -q "ExecStart.*services\." "$service_file"; then
        sed -i "s|ExecStart=.*python3.*services\.|ExecStart=/usr/bin/python3 services.|g" "$service_file"
        success "تم تحديث ExecStart (services)"
    fi
    
    if grep -q "ExecStart.*bots\." "$service_file"; then
        sed -i "s|ExecStart=.*python3.*bots\.|ExecStart=/usr/bin/python3 bots.|g" "$service_file"
        success "تم تحديث ExecStart (bots)"
    fi
    
    # إضافة PYTHONPATH إذا لزم
    if ! grep -q "Environment=PYTHONPATH" "$service_file"; then
        sed -i "/WorkingDirectory=.*/a Environment=PYTHONPATH=$APP_ROOT" "$service_file"
        success "تم إضافة PYTHONPATH"
    fi
    
    success "تم نقل $service بنجاح"
}

# تطبيق التغييرات
apply_changes() {
    section "تطبيق التغييرات"
    
    systemctl daemon-reload
    success "تم إعادة تحميل systemd"
    
    # إعادة تشغيل الخدمات المنقولة
    for service in "${SERVICES_TO_MIGRATE[@]}"; do
        echo "🔄 إعادة تشغيل $service"
        systemctl restart "$service" 2>/dev/null && success "تم تشغيل $service" || warning "تعذر تشغيل $service (قد تحتاج إصلاح إضافي)"
    done
}

# تقرير نهائي
generate_report() {
    section "تقرير النقل النهائي"
    
    echo "📊 النتائج:"
    echo "   الخدمات المنقولة: ${#SERVICES_TO_MIGRATE[@]}"
    
    echo -e "\n🔍 فحص الخدمات بعد النقل:"
    for service in "${SERVICES_TO_MIGRATE[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            success "$service - نشطة"
        else
            warning "$service - غير نشطة (تحتاج فحص)"
        fi
    done
}

main() {
    section "بدء نقل جميع خدمات السويت إلى الداخل"
    
    discover_external_services
    
    if [ ${#SERVICES_TO_MIGRATE[@]} -eq 0 ]; then
        success "لا توجد خدمات تحتاج نقل - كل الخدمات بالفعل داخل السويت!"
        return 0
    fi
    
    # نقل كل الخدمات
    for service in "${SERVICES_TO_MIGRATE[@]}"; do
        migrate_service "$service"
    done
    
    apply_changes
    generate_report
    
    section "🎉 تم الانتهاء من نقل جميع الخدمات داخل السويت!"
}

main "$@"

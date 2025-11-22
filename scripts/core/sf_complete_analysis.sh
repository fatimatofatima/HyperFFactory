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
ok()      { echo -e "${GREEN}[✓] $*${NC}"; }
warn()    { echo -e "${YELLOW}[!] $*${NC}"; }
err()     { echo -e "${RED}[✗] $*${NC}"; }

APP_ROOT="/opt/smartfriend-suite"

# فحص شامل لهيكل المشروع
analyze_project_structure() {
    section "تحليل هيكل مشروع SmartFriend Suite"
    
    echo "المجلد الرئيسي: $APP_ROOT"
    echo "المساحة المستخدمة: $(du -sh $APP_ROOT 2>/dev/null | cut -f1) || غير متاح"
    
    # فحص الهيكل الأساسي
    info "الهيكل الأساسي للمشروع:"
    find "$APP_ROOT" -maxdepth 2 -type d -name "*apps*" -o -name "*services*" -o -name "*factory*" | sort | head -20
    
    # البحث عن جميع ملفات main.py
    info "البحث عن جميع ملفات main.py:"
    local main_files=$(find "$APP_ROOT" -name "main.py" -type f | grep -v "__pycache__" | grep -v "venv" | head -30)
    echo "$main_files"
    
    # عد الملفات
    local total_main=$(echo "$main_files" | wc -l)
    info "إجمالي ملفات main.py الموجودة: $total_main"
}

# فحص تفصيلي لملفات ffactory
analyze_ffactory_structure() {
    section "تحليل هيكل ffactory"
    
    # البحث عن جميع مجلدات ffactory
    info "مجلدات ffactory الموجودة:"
    find "$APP_ROOT" -type d -name "*ffactory*" | grep -v "__pycache__" | grep -v "venv"
    
    # فحص محتويات services/ffactory/ (المجلد النشط)
    local active_ffactory="$APP_ROOT/services/ffactory"
    if [ -d "$active_ffactory" ]; then
        info "محتوى المجلد النشط services/ffactory/:"
        ls -la "$active_ffactory"
        
        # فحص محتوى الملفات
        for file in "$active_ffactory"/*.py; do
            if [ -f "$file" ]; then
                info "تحليل الملف: $(basename "$file")"
                echo "    السطور الأولى:"
                head -5 "$file" | sed 's/^/        /'
                echo "    السطور الأخيرة:"
                tail -3 "$file" | sed 's/^/        /'
                echo
            fi
        done
    fi
    
    # فحص إذا كان هناك apps/ffactory/
    local apps_ffactory="$APP_ROOT/apps/ffactory"
    if [ -d "$apps_ffactory" ]; then
        warn "يوجد مجلد apps/ffactory/ لكنه قد لا يكون مستخدمًا"
        ls -la "$apps_ffactory"
    else
        ok "لا يوجد مجلد apps/ffactory/ - هذا متوقع"
    fi
}

# فحص خدمات systemd المفصلة
analyze_systemd_services() {
    section "تحليل مفصل لخدمات systemd"
    
    # قائمة الخدمات الأساسية
    local core_services=(
        sf-core.service sf-health.service sf-memory.service
        sf-bot.service sf-web.service sf-telegram.service
        smartfrind-core.service
    )
    
    for service in "${core_services[@]}"; do
        echo
        info "تحليل الخدمة: $service"
        
        local service_file="/etc/systemd/system/$service"
        
        if [ -f "$service_file" ]; then
            ok "ملف الخدمة موجود"
            
            # عرض محتوى الخدمة
            echo "    محتوى ملف الخدمة:"
            cat "$service_file" | sed 's/^/        /'
            
            # فحص حالة الخدمة
            local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
            local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
            echo "    الحالة: active=$status, enabled=$enabled"
            
            # فحص السجلات إذا كانت الخدمة فاشلة
            if [ "$status" = "failed" ] || [ "$status" = "activating" ]; then
                warn "الخدمة بها مشاكل، السجلات الحديثة:"
                journalctl -u "$service" -n 5 --no-pager 2>/dev/null | sed 's/^/        /' || echo "        لا توجد سجلات"
            fi
            
        else
            err "ملف الخدمة غير موجود: $service_file"
        fi
    done
}

# فحص وإصلاح خدمة sf-core.service
fix_sf_core_service() {
    section "إصلاح خدمة sf-core.service"
    
    local service_file="/etc/systemd/system/sf-core.service"
    
    if [ ! -f "$service_file" ]; then
        err "ملف الخدمة غير موجود: $service_file"
        return 1
    fi
    
    # نسخ احتياطي
    local backup_file="$service_file.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$service_file" "$backup_file"
    ok "تم إنشاء نسخة احتياطية: $backup_file"
    
    # البحث عن التطبيق الصحيح
    info "البحث عن التطبيق الصحيح لـ sf-core..."
    
    # الخيار 1: services/ffactory/simple_api.py
    local candidate1="$APP_ROOT/services/ffactory/simple_api.py"
    # الخيار 2: smartfrind/app/api/main.py  
    local candidate2="$APP_ROOT/smartfrind/app/api/main.py"
    # الخيار 3: services/ffactory/vision_api.py
    local candidate3="$APP_ROOT/services/ffactory/vision_api.py"
    
    local selected_app=""
    
    if [ -f "$candidate1" ]; then
        selected_app="services.ffactory.simple_api"
        ok "تم العثور على التطبيق: $candidate1"
    elif [ -f "$candidate2" ]; then
        selected_app="smartfrind.app.api.main" 
        ok "تم العثور على التطبيق: $candidate2"
    elif [ -f "$candidate3" ]; then
        selected_app="services.ffactory.vision_api"
        ok "تم العثور على التطبيق: $candidate3"
    else
        err "لم يتم العثور على أي تطبيق مناسب!"
        return 1
    fi
    
    # تعديل الخدمة
    info "تعديل الخدمة لاستخدام: $selected_app"
    
    # استبدال apps.ffactory.main بالتطبيق الصحيح
    sed -i "s|apps\.ffactory\.main|$selected_app|g" "$service_file"
    
    # التحقق من التعديل
    if grep -q "$selected_app" "$service_file"; then
        ok "تم تعديل الخدمة بنجاح"
        echo "    المحتوى بعد التعديل:"
        grep "ExecStart" "$service_file" | sed 's/^/        /'
    else
        err "فشل في تعديل الخدمة"
        return 1
    fi
    
    # إعادة تحميل systemd
    systemctl daemon-reload
    ok "تم إعادة تحميل systemd"
    
    # محاولة تشغيل الخدمة
    info "محاولة تشغيل الخدمة..."
    systemctl restart sf-core.service
    sleep 2
    
    local status=$(systemctl is-active sf-core.service)
    if [ "$status" = "active" ]; then
        ok "الخدمة تعمل بنجاح الآن!"
    else
        warn "الخدمة لا تزال بها مشاكل"
        journalctl -u sf-core.service -n 10 --no-pager | sed 's/^/    /'
    fi
}

# فحص الاعتماديات والمتطلبات
check_dependencies() {
    section "فحص الاعتماديات والمتطلبات"
    
    # فحص وجود Python virtual environments
    info "بيئات Python الافتراضية:"
    find "$APP_ROOT" -name "venv" -type d | head -5
    
    # فحص ملفات المتطلبات
    info "ملفات المتطلبات:"
    find "$APP_ROOT" -name "requirements*.txt" -o -name "pyproject.toml" -o -name "setup.py" | head -10
    
    # فحص إعدادات Python
    info "مسارات Python:"
    python3 -c "import sys; print('\n'.join(sys.path))" 2>/dev/null | head -10 || warn "لا يمكن فحص مسارات Python"
}

# تقرير شامل
generate_report() {
    section "تقرير شامل"
    
    echo "ملخص النتائج:"
    echo "=============="
    
    # حالة الخدمات الأساسية
    info "حالة الخدمات الأساسية:"
    for service in sf-core.service sf-health.service sf-memory.service; do
        local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
        echo "    $service: $status"
    done
    
    # التوصيات
    echo
    info "التوصيات:"
    echo "    1. خدمة sf-core.service تم إصلاحها لاستخدام المسار الصحيح"
    echo "    2. الخدمات الأخرى تحتاج فحصًا فرديًا"
    echo "    3. تأكد من وجود جميع الاعتماديات المطلوبة"
    echo "    4. تحقق من ملفات .env وإعدادات البيئة"
}

main() {
    section "بدء التحليل الشامل لـ SmartFriend Suite"
    
    analyze_project_structure
    analyze_ffactory_structure  
    analyze_systemd_services
    check_dependencies
    fix_sf_core_service
    generate_report
    
    section "تم الانتهاء من التحليل الشامل"
    echo "يمكنك الآن فحص الخدمات باستخدام: systemctl status sf-core.service"
    echo "لرؤية السجلات: journalctl -u sf-core.service -f"
}

main "$@"

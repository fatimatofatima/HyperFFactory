#!/usr/bin/env bash
set -Eeuo pipefail

FAILED_SERVICES=(
    "sf-unified.service"
    "sf-memory.service" 
    "sf-web.service"
    "sf-spider.service"
    "sf-health.service"
)

REPORT_DIR="/opt/smartfriend-suite/reports"
TS="$(date '+%Y%m%d_%H%M%S')"
REPORT="$REPORT_DIR/sf_fix_services_${TS}.log"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$REPORT"; }

diagnose_service() {
    local service="$1"
    
    log "🔍 تشخيص الخدمة: $service"
    
    # 1. التحقق من وجود ملف الخدمة
    local service_file="/etc/systemd/system/$service"
    if [[ ! -f "$service_file" ]]; then
        log "   ❌ ملف الخدمة غير موجود: $service_file"
        return 1
    fi
    log "   ✅ ملف الخدمة موجود"
    
    # 2. التحقق من صلاحيات التنفيذ
    local exec_start=$(grep "ExecStart=" "$service_file" | head -1)
    local binary_path=$(echo "$exec_start" | cut -d'=' -f2 | awk '{print $1}')
    
    if [[ -n "$binary_path" ]]; then
        if [[ -f "$binary_path" ]]; then
            if [[ -x "$binary_path" ]]; then
                log "   ✅ الملف القابل للتنفيذ: $binary_path"
            else
                log "   ⚠️  الملف غير قابل للتنفيذ: $binary_path"
                chmod +x "$binary_path" && log "   🔧 تم جعله قابل للتنفيذ"
            fi
        else
            log "   ❌ الملف غير موجود: $binary_path"
        fi
    fi
    
    # 3. التحقق من ملفات البيئة
    local env_files=$(grep "EnvironmentFile=" "$service_file" | cut -d'=' -f2)
    for env_file in $env_files; do
        if [[ -f "$env_file" ]]; then
            log "   ✅ ملف البيئة موجود: $env_file"
        else
            log "   ❌ ملف البيئة مفقود: $env_file"
        fi
    done
    
    # 4. عرض آخر أخطاء الخدمة
    log "   📋 آخر سطور اللوج:"
    journalctl -u "$service" -n 10 --no-pager 2>/dev/null | tail -5 | while read line; do
        log "      $line"
    done || log "      لا توجد سجلات"
}

fix_service() {
    local service="$1"
    
    log "🔧 محاولة إصلاح: $service"
    
    # 1. إيقاف الخدمة أولاً
    systemctl stop "$service" 2>/dev/null && log "   ⏹️  تم إيقاف الخدمة"
    
    # 2. إعادة تحميل systemd
    systemctl daemon-reload && log "   🔄 تم إعادة تحميل systemd"
    
    # 3. إعادة التشغيل
    if systemctl start "$service"; then
        log "   ✅ تم بدء الخدمة بنجاح"
        return 0
    else
        log "   ❌ فشل بدء الخدمة"
        return 1
    fi
}

main() {
    log "بدء تشخيص وإصلاح الخدمات الفاشلة"
    log "=================================="
    
    # تشخيص جميع الخدمات الفاشلة
    for service in "${FAILED_SERVICES[@]}"; do
        diagnose_service "$service"
        echo 
    done
    
    log "=================================="
    log "بدء محاولات الإصلاح"
    log "=================================="
    
    # محاولة إصلاح الخدمات
    local fixed_count=0
    for service in "${FAILED_SERVICES[@]}"; do
        if fix_service "$service"; then
            ((fixed_count++))
        fi
        echo
    done
    
    log "🎯 نتيجة الإصلاح: $fixed_count من ${#FAILED_SERVICES[@]} خدمة تم إصلاحها"
    
    # عرض الحالة النهائية
    log "📊 الحالة النهائية للخدمات:"
    for service in "${FAILED_SERVICES[@]}"; do
        local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
        log "   $service: $status"
    done
    
    log "تم إنشاء التقرير: $REPORT"
}

main

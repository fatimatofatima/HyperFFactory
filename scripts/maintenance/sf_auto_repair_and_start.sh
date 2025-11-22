#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "[$(date '+%F %T')] $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; }

main() {
    log "${BLUE}=== SmartFriend Suite - الإصلاح والتشغيل الآلي ===${NC}"
    
    # 1. إصلاح Brain Stack
    section "إصلاح Brain Stack"
    repair_brain_stack
    
    # 2. تشغيل Core Services
    section "تشغيل Core Services"
    start_core_services
    
    # 3. فحص وعلاج المشاكل
    section "فحص وعلاج المشاكل"
    diagnose_and_fix
    
    # 4. التحقق النهائي
    section "التحقق النهائي"
    final_verification
    
    success "اكتمل الإصلاح والتشغيل الآلي"
}

repair_brain_stack() {
    info "إصلاح Brain Stack..."
    
    if [[ -f "/root/sf_suite_brain_fix.sh" ]]; then
        /root/sf_suite_brain_fix.sh
        success "تم إصلاح Brain Stack"
    else
        error "لم يتم العثور على سكربت إصلاح Brain Stack"
        return 1
    fi
}

start_core_services() {
    info "تشغيل Core Services..."
    
    if [[ -f "/root/sf_suite_core_autorun.sh" ]]; then
        /root/sf_suite_core_autorun.sh
        success "تم تشغيل Core Services"
    else
        error "لم يتم العثور على سكربت تشغيل Core Services"
        return 1
    fi
}

diagnose_and_fix() {
    info "فحص وعلاج المشاكل..."
    
    # فحص Brain Stack
    check_brain_services
    
    # فحص Core Services
    check_core_services
    
    # فحص ffactory
    check_ffactory
}

check_brain_services() {
    info "فحص خدمات Brain..."
    
    local brain_services=("sf-ingest" "sf-learn" "sf-learning" "sf-kb-build" "sf-fts-maint")
    
    for service in "${brain_services[@]}"; do
        if systemctl is-enabled "$service.service" >/dev/null 2>&1; then
            if systemctl is-active "$service.service" >/dev/null 2>&1; then
                success "$service.service: نشط"
            else
                warning "$service.service: مفعل ولكن غير نشط - جاري التشغيل..."
                systemctl start "$service.service" && success "تم تشغيل $service.service" || error "فشل تشغيل $service.service"
            fi
        else
            warning "$service.service: غير مفعل - جاري التفعيل..."
            systemctl enable "$service.service" && systemctl start "$service.service" && success "تم تفعيل وتشغيل $service.service" || error "فشل تفعيل $service.service"
        fi
    done
}

check_core_services() {
    info "فحص خدمات Core..."
    
    local core_services=("sf-health" "sf-memory" "sf-unified")
    
    for service in "${core_services[@]}"; do
        if systemctl is-active "$service.service" >/dev/null 2>&1; then
            success "$service.service: نشط"
        else
            warning "$service.service: غير نشط - جاري التشغيل..."
            systemctl start "$service.service" && success "تم تشغيل $service.service" || error "فشل تشغيل $service.service"
        fi
    done
}

check_ffactory() {
    info "فحص ffactory..."
    
    if systemctl is-active "ff-doctor.service" >/dev/null 2>&1; then
        success "ff-doctor.service: نشط"
    else
        warning "ff-doctor.service: غير نشط - جاري التشغيل..."
        systemctl start "ff-doctor.service" && success "تم تشغيل ff-doctor.service" || {
            error "فشل تشغيل ff-doctor.service - قد يحتاج إصلاح إضافي"
            log "تشغيل تشخيص مفصل لـ ff-doctor..."
            systemctl status ff-doctor.service --no-pager
        }
    fi
}

final_verification() {
    info "التحقق النهائي..."
    
    echo "=== حالة الخدمات النهائية ==="
    systemctl list-units 'sf-*' 'ff-doctor*' --no-legend | head -20
    
    echo "=== المنافذ النشطة ==="
    ss -tlnp | grep -E ':(8210|8214|8220|8330|8390|8170)' || warning "لا توجد منافذ نشطة"
    
    echo "=== العمليات النشطة ==="
    ps aux | grep -E '(sf-|ff-doctor)' | grep -v grep | head -10
}

info() { echo -e "${BLUE}ℹ️ $*${NC}"; }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

main "$@"

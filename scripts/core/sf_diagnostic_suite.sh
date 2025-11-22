#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "[$(date '+%F %T')] $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠️ $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; }
info() { echo -e "${CYAN}ℹ️ $*${NC}"; }

# متغيرات
TS=$(date '+%Y%m%d_%H%M%S')
REPORT_DIR="/root/sf_diagnostics_${TS}"
mkdir -p "$REPORT_DIR"

main() {
    log "${BLUE}=== SmartFriend Suite - الفحص الشامل والتشخيص ===${NC}"
    
    # 1. فحص النظام الأساسي
    section "فحص النظام الأساسي"
    check_system_resources
    check_disk_space
    check_network
    
    # 2. فحص الخدمات
    section "فحص الخدمات"
    check_sf_services
    check_ff_services
    check_smartfrind_services
    
    # 3. فحص التطبيقات
    section "فحص التطبيقات"
    check_python_envs
    check_applications
    check_ports
    
    # 4. فحص البيانات
    section "فحص البيانات"
    check_databases
    check_logs
    
    # 5. التوصيات
    section "التوصيات والإصلاحات"
    generate_recommendations
    
    success "تم الانتهاء من الفحص الشامل"
    info "التقرير الكامل في: $REPORT_DIR"
}

check_system_resources() {
    info "فحص موارد النظام..."
    
    echo "=== استخدام الذاكرة ===" > "$REPORT_DIR/system_memory.txt"
    free -h >> "$REPORT_DIR/system_memory.txt"
    
    echo "=== استخدام CPU ===" > "$REPORT_DIR/system_cpu.txt"
    top -bn1 | head -20 >> "$REPORT_DIR/system_cpu.txt"
    
    echo "=== العمليات النشطة ===" > "$REPORT_DIR/system_processes.txt"
    ps aux --sort=-%cpu | head -20 >> "$REPORT_DIR/system_processes.txt"
}

check_disk_space() {
    info "فحص مساحة التخزين..."
    
    echo "=== مساحة التخزين ===" > "$REPORT_DIR/disk_space.txt"
    df -h >> "$REPORT_DIR/disk_space.txt"
    
    echo "=== أكبر الملفات ===" >> "$REPORT_DIR/disk_space.txt"
    find /opt/smartfriend-suite -type f -exec du -h {} + 2>/dev/null | sort -rh | head -20 >> "$REPORT_DIR/disk_space.txt"
}

check_network() {
    info "فحص الشبكة والمنافذ..."
    
    echo "=== المنافذ المستخدمة ===" > "$REPORT_DIR/network_ports.txt"
    ss -tlnp | grep -E ':(8210|8214|8220|8330|8390|8170)' >> "$REPORT_DIR/network_ports.txt"
}

check_sf_services() {
    info "فحص خدمات sf-*..."
    
    echo "=== حالة خدمات sf-* ===" > "$REPORT_DIR/sf_services.txt"
    systemctl list-units 'sf-*' --all --no-legend >> "$REPORT_DIR/sf_services.txt"
    
    echo "=== تفاصيل Brain Stack ===" >> "$REPORT_DIR/sf_services.txt"
    for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint sf-spider; do
        echo "--- $service ---" >> "$REPORT_DIR/sf_services.txt"
        systemctl is-active "$service.service" >> "$REPORT_DIR/sf_services.txt" 2>&1
        systemctl is-enabled "$service.service" >> "$REPORT_DIR/sf_services.txt" 2>&1
    done
}

check_ff_services() {
    info "فحص خدمات ff-*..."
    
    echo "=== حالة خدمات ff-* ===" > "$REPORT_DIR/ff_services.txt"
    systemctl list-units 'ff-*' --all --no-legend >> "$REPORT_DIR/ff_services.txt"
}

check_smartfrind_services() {
    info "فحص خدمات smartfrind-*..."
    
    echo "=== حالة خدمات smartfrind-* ===" > "$REPORT_DIR/smartfrind_services.txt"
    systemctl list-units 'smartfrind-*' --all --no-legend >> "$REPORT_DIR/smartfrind_services.txt"
}

check_python_envs() {
    info "فحص بيئات Python..."
    
    echo "=== بيئات Python المكتشفة ===" > "$REPORT_DIR/python_envs.txt"
    find /opt -name "venv" -type d 2>/dev/null | head -10 >> "$REPORT_DIR/python_envs.txt"
    
    for venv in $(find /opt -name "venv" -type d 2>/dev/null | head -5); do
        if [[ -f "$venv/bin/python" ]]; then
            echo "--- $venv ---" >> "$REPORT_DIR/python_envs.txt"
            "$venv/bin/python" --version >> "$REPORT_DIR/python_envs.txt" 2>&1
        fi
    done
}

check_applications() {
    info "فحص التطبيقات..."
    
    echo "=== التطبيقات الرئيسية ===" > "$REPORT_DIR/applications.txt"
    find /opt/smartfriend-suite -name "*.py" -type f | head -30 >> "$REPORT_DIR/applications.txt"
}

check_ports() {
    info "فحص منافذ التطبيقات..."
    
    echo "=== التطبيقات والمنافذ ===" > "$REPORT_DIR/application_ports.txt"
    netstat -tlnp | grep -E '(8210|8214|8220|8330|8390|8170)' >> "$REPORT_DIR/application_ports.txt" 2>&1
}

check_databases() {
    info "فحص قواعد البيانات..."
    
    echo "=== قواعد البيانات ===" > "$REPORT_DIR/databases.txt"
    find /opt/smartfriend-suite -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | head -20 >> "$REPORT_DIR/databases.txt"
    
    for db in $(find /opt/smartfriend-suite -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | head -5); do
        echo "--- $db ---" >> "$REPORT_DIR/databases.txt"
        ls -la "$db" >> "$REPORT_DIR/databases.txt" 2>&1
    done
}

check_logs() {
    info "فحص السجلات..."
    
    echo "=== آخر السجلات ===" > "$REPORT_DIR/recent_logs.txt"
    find /opt/smartfriend-suite -name "*.log" -type f -exec ls -la {} + 2>/dev/null | sort -k6,7 | tail -10 >> "$REPORT_DIR/recent_logs.txt"
}

generate_recommendations() {
    info "إنشاء التوصيات..."
    
    echo "=== التوصيات والإصلاحات ===" > "$REPORT_DIR/recommendations.txt"
    
    # فحص Brain Stack
    for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint; do
        if ! systemctl is-active "$service.service" >/dev/null 2>&1; then
            echo "❌ $service.service: غير نشط - يحتاج تشغيل" >> "$REPORT_DIR/recommendations.txt"
        fi
    done
    
    # فحص Core Services
    for service in sf-health sf-memory sf-unified; do
        if systemctl is-active "$service.service" >/dev/null 2>&1; then
            echo "✅ $service.service: نشط" >> "$REPORT_DIR/recommendations.txt"
        else
            echo "❌ $service.service: غير نشط - يحتاج إصلاح" >> "$REPORT_DIR/recommendations.txt"
        fi
    done
    
    # فحص ff-doctor
    if systemctl is-active "ff-doctor.service" >/dev/null 2>&1; then
        echo "✅ ff-doctor.service: نشط" >> "$REPORT_DIR/recommendations.txt"
    else
        echo "❌ ff-doctor.service: معطل - تم إنشاء المستخدم ولكن يحتاج فحص إضافي" >> "$REPORT_DIR/recommendations.txt"
    fi
    
    # توصيات عامة
    echo "" >> "$REPORT_DIR/recommendations.txt"
    echo "🎯 الخطوات المقترحة:" >> "$REPORT_DIR/recommendations.txt"
    echo "1. تشغيل: /root/sf_suite_brain_fix.sh (لإصلاح Brain Stack)" >> "$REPORT_DIR/recommendations.txt"
    echo "2. تشغيل: /root/sf_suite_core_autorun.sh (لتشغيل Core Services)" >> "$REPORT_DIR/recommendations.txt"
    echo "3. فحص: systemctl status ff-doctor.service (لمشكلة ff-doctor)" >> "$REPORT_DIR/recommendations.txt"
}

section() {
    echo -e "\n${BLUE}=== $1 ===${NC}"
}

main "$@"

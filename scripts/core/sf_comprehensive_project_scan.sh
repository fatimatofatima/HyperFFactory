#!/bin/bash

# =============================================================================
# SmartFriend Suite - المسح الشامل للمشروع والتطبيقات والخدمات
# =============================================================================

set -euo pipefail

# التوقيت والمجلدات
TS=$(date '+%Y%m%d_%H%M%S')
SCAN_DIR="/root/sf_project_scan"
REPORT="${SCAN_DIR}/comprehensive_project_scan_${TS}.log"
MAIN_SUITE="/opt/smartfriend-suite"

# إنشاء مجلد المسح
mkdir -p "$SCAN_DIR"

# دالة التسجيل
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$REPORT"
}

section() {
    echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') === $1 ===" | tee -a "$REPORT"
    echo "==================================================================" | tee -a "$REPORT"
}

# بدء المسح
echo "🔍 SmartFriend Suite - المسح الشامل للمشروع" | tee "$REPORT"
echo "⏰ الوقت: $(date)" | tee -a "$REPORT"
echo "📁 تقرير: $REPORT" | tee -a "$REPORT"

# =============================================================================
# القسم 1: حالة النظام الأساسية
# =============================================================================
section "1. حالة النظام الأساسية"

log "🖥️  معلومات النظام:"
hostnamectl | tee -a "$REPORT"

log "💾 مساحة التخزين:"
df -h / /opt /var | tee -a "$REPORT"

log "🧠 استخدام الذاكرة:"
free -h | tee -a "$REPORT"

# =============================================================================
# القسم 2: المسح الشامل للخدمات
# =============================================================================
section "2. المسح الشامل للخدمات"

log "📊 جميع خدمات sf-*:"
systemctl list-units 'sf-*' --all --no-legend | tee -a "$REPORT"

log "📊 جميع خدمات ff-*:"
systemctl list-units 'ff-*' --all --no-legend | tee -a "$REPORT"

log "📊 جميع خدمات smartfrind-*:"
systemctl list-units 'smartfrind-*' --all --no-legend | tee -a "$REPORT"

log "🔍 تفاصيل خدمات Brain Stack:"
for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint sf-spider; do
    log "--- $service.service ---"
    systemctl status "$service.service" --no-pager | head -10 | tee -a "$REPORT"
    if systemctl is-active "$service.service" >/dev/null 2>&1; then
        log "✅ $service: نشط"
    else
        log "❌ $service: غير نشط"
    fi
done

# =============================================================================
# القسم 3: هيكل المشروع والتطبيقات
# =============================================================================
section "3. هيكل المشروع والتطبيقات"

# التحقق من وجود المجلد الرئيسي
if [[ -d "$MAIN_SUITE" ]]; then
    log "📁 هيكل $MAIN_SUITE:"
    find "$MAIN_SUITE" -maxdepth 3 -type d | sort | tee -a "$REPORT"
    
    log "🐍 بيئة Python:"
    if [[ -f "$MAIN_SUITE/venv/bin/python" ]]; then
        log "✅ تم العثور على venv: $MAIN_SUITE/venv/bin/python"
        "$MAIN_SUITE/venv/bin/python" --version | tee -a "$REPORT"
    else
        log "❌ لم يتم العثور على venv"
    fi
    
    log "📝 السكربتات المتاحة:"
    find "$MAIN_SUITE" -name "*.py" -o -name "*.sh" | head -20 | tee -a "$REPORT"
else
    log "❌ المجلد الرئيسي غير موجود: $MAIN_SUITE"
fi

# =============================================================================
# القسم 4: التطبيقات النشطة والمنافذ
# =============================================================================
section "4. التطبيقات النشطة والمنافذ"

log "🌐 المنافذ المستخدمة:"
ss -tlnp | grep -E ':(8210|8214|8220|8330|8390|8170)' | tee -a "$REPORT"

log "🔄 العمليات النشطة:"
ps aux | grep -E '(sf-|smartfrind|python)' | grep -v grep | head -20 | tee -a "$REPORT"

# =============================================================================
# القسم 5: تحليل ملفات الخدمات
# =============================================================================
section "5. تحليل ملفات الخدمات"

log "📋 تحليل ExecStart لخدمات Brain:"
for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint; do
    service_file="/etc/systemd/system/${service}.service"
    if [[ -f "$service_file" ]]; then
        log "--- $service.service ---"
        grep -E "^(ExecStart|WorkingDirectory|User)=" "$service_file" | tee -a "$REPORT"
    else
        log "❌ ملف الخدمة غير موجود: $service_file"
    fi
done

# =============================================================================
# القسم 6: التبعيات والعلاقات
# =============================================================================
section "6. التبعيات والعلاقات"

log "🔗 تبعيات الخدمات:"
for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint; do
    if systemctl cat "$service.service" >/dev/null 2>&1; then
        log "--- $service.service ---"
        systemctl show "$service.service" --property=Requires --property=After --property=Wants | tee -a "$REPORT"
    fi
done

# =============================================================================
# القسم 7: التوصيات والتحليل
# =============================================================================
section "7. التوصيات والتحليل"

log "📈 التحليل التلخيصي:"

# عد الخدمات حسب النوع
sf_count=$(systemctl list-units 'sf-*' --all --no-legend | wc -l)
ff_count=$(systemctl list-units 'ff-*' --all --no-legend | wc -l)
smartfrind_count=$(systemctl list-units 'smartfrind-*' --all --no-legend | wc -l)

log "📊 إحصائيات الخدمات:"
log "   • sf-* services: $sf_count"
log "   • ff-* services: $ff_count" 
log "   • smartfrind-* services: $smartfrind_count"

# تحليل Brain Stack
log "🧠 تحليل Brain Stack:"
brain_services=("sf-ingest" "sf-learn" "sf-learning" "sf-kb-build" "sf-fts-maint" "sf-spider")
for service in "${brain_services[@]}"; do
    if systemctl is-enabled "$service.service" >/dev/null 2>&1; then
        status=$(systemctl is-active "$service.service")
        exec_start=$(systemctl show "$service.service" --property=ExecStart --value 2>/dev/null || echo "غير معروف")
        log "   • $service: $status | $exec_start"
    else
        log "   • $service: غير مفعل"
    fi
done

# التوصيات
log "💡 التوصيات:"
if [[ ! -f "/opt/smartfriend-suite/venv/bin/python" ]]; then
    log "   ⚠️  إنشاء venv في /opt/smartfriend-suite/venv"
fi

# التحقق من Brain Stack
for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint; do
    exec_start=$(systemctl show "$service.service" --property=ExecStart --value 2>/dev/null || echo "")
    if [[ "$exec_start" == *"/usr/bin/python3"* ]]; then
        log "   ⚠️  $service: يحتاج إعادة ربط مع venv السيوت"
    fi
done

# =============================================================================
# نهاية المسح
# =============================================================================
section "نهاية المسح"

log "✅ تم الانتهاء من المسح الشامل"
log "📊 التقرير المحفوظ في: $REPORT"
log "🔍 للمراجعة: cat $REPORT"

echo -e "\n🎯 الخطوات التالية المقترحة:"
echo "   1. مراجعة تقرير المسح: cat $REPORT"
echo "   2. إصلاح Brain Stack باستخدام: /root/sf_suite_brain_fix.sh"
echo "   3. التحقق من الهيكل: /root/sf_suite_tracks_report.sh"


#!/bin/bash

# =============================================================================
# SmartFriend Suite - جرد المشروع الشامل (ملفات + تطبيقات + مسارات + خدمات)
# =============================================================================

set -euo pipefail

TS=$(date '+%Y%m%d_%H%M%S')
SCAN_DIR="/root/sf_project_scan"
REPORT="${SCAN_DIR}/project_inventory_${TS}.log"
MAIN_SUITE="/opt/smartfriend-suite"

mkdir -p "$SCAN_DIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$REPORT"; }
section() { echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') === $1 ===" | tee -a "$REPORT"; }

# =============================================================================
# بدء الجرد الشامل
# =============================================================================

section "🎯 بدء جرد مشروع SmartFriend Suite الشامل"

# =============================================================================
# 1. جرد الملفات والهيكل
# =============================================================================

section "1. 📁 جرد الملفات والهيكل"

log "المسار الرئيسي: $MAIN_SUITE"
log "الحجم الكلي: $(du -sh "$MAIN_SUITE" 2>/dev/null || echo 'غير موجود')"

# التصنيف المنطقي للمجلدات
log "التصنيف المنطقي للمجلدات:"

log "🎯 طبقة الكور (Core Runtime):"
for dir in smartfriend/app smartfriend/venv core smart_core gateway health apps tools skills; do
    if [ -d "$MAIN_SUITE/$dir" ]; then
        size=$(du -sh "$MAIN_SUITE/$dir" 2>/dev/null | cut -f1)
        log "  ✅ $size - $dir"
    fi
done

log "🗄️ طبقة البيانات (Data Layer):"
for dir in var data mem inbox logs reports backups; do
    if [ -d "$MAIN_SUITE/$dir" ]; then
        size=$(du -sh "$MAIN_SUITE/$dir" 2>/dev/null | cut -f1)
        log "  ✅ $size - $dir"
    fi
done

log "⚙️ طبقة التشغيل (Ops Layer):"
for dir in scripts bin ops factory integrations engineering_seed cognitive_system legacy_integration; do
    if [ -d "$MAIN_SUITE/$dir" ]; then
        size=$(du -sh "$MAIN_SUITE/$dir" 2>/dev/null | cut -f1)
        log "  ✅ $size - $dir"
    fi
done

log "🖥️ طبقة الواجهة (UI Layer):"
for dir in admin-ui docs staging_skills config; do
    if [ -d "$MAIN_SUITE/$dir" ]; then
        size=$(du -sh "$MAIN_SUITE/$dir" 2>/dev/null | cut -f1)
        log "  ✅ $size - $dir"
    fi
done

log "📚 طبقة الليجاسي (Legacy Layer):"
for dir in smartfrind my-frind _smartfrind_migration _gists_import ENV __pycache__; do
    if [ -d "$MAIN_SUITE/$dir" ]; then
        size=$(du -sh "$MAIN_SUITE/$dir" 2>/dev/null | cut -f1)
        log "  📜 $size - $dir"
    fi
done

# =============================================================================
# 2. جرد التطبيقات والوحدات
# =============================================================================

section "2. 🐍 جرد التطبيقات والوحدات"

log "التطبيقات الرئيسية المكتشفة:"
find "$MAIN_SUITE" -name "*.py" -type f | grep -E "(app|main|api|bot|core|gateway|health|memory|learning|spider|ingest)" | head -30 | while read pyfile; do
    dir=$(dirname "$pyfile")
    base=$(basename "$pyfile")
    log "  📄 $dir/$base"
done

# =============================================================================
# 3. جرد قواعد البيانات
# =============================================================================

section "3. 🗄️ جرد قواعد البيانات"

log "قواعد البيانات الرئيسية:"
find "$MAIN_SUITE" -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" 2>/dev/null | while read dbfile; do
    size=$(du -h "$dbfile" 2>/dev/null | cut -f1)
    log "  💾 $size - $dbfile"
done

# =============================================================================
# 4. جرد الخدمات Systemd
# =============================================================================

section "4. ⚙️ جرد الخدمات Systemd"

log "🟢 خدمات السويت الرسمية (sf-*):"
systemctl list-units --all "sf-*" 2>/dev/null | while read unit; do
    log "  ✅ $unit"
done

log "🟡 خدمات SmartFrind (smartfrind-*):"
systemctl list-units --all "smartfrind-*" 2>/dev/null | while read unit; do
    log "  📜 $unit"
done

log "🔴 خدمات SmartFriend القديمة (smartfriend-*):"
systemctl list-units --all "smartfriend-*" 2>/dev/null | while read unit; do
    log "  🗑️ $unit"
done

log "🏭 خدمات FFactory (ff-*):"
systemctl list-units --all "ff*" 2>/dev/null | while read unit; do
    log "  🏭 $unit"
done

# =============================================================================
# 5. جرد المنافذ والاتصالات
# =============================================================================

section "5. 🌐 جرد المنافذ والاتصالات"

log "المنافذ النشطة للسويت:"
ss -tulpn | grep -E ":(8210|8211|8212|8213|8214|8220|8221|8222|8223|8330|8383|8390|8170)" | while read conn; do
    log "  🔌 $conn"
done

# =============================================================================
# 6. جرد العمليات النشطة
# =============================================================================

section "6. 🚀 جرد العمليات النشطة"

log "عمليات SmartFriend الجارية:"
ps aux | grep -E "(smartfriend|smartfrind|ffactory)" | grep -v grep | head -20 | while read process; do
    log "  💻 $process"
done

# =============================================================================
# 7. الإحصائيات النهائية
# =============================================================================

section "7. 📊 الإحصائيات النهائية"

total_dirs=$(find "$MAIN_SUITE" -type d 2>/dev/null | wc -l)
total_files=$(find "$MAIN_SUITE" -type f 2>/dev/null | wc -l)
total_py_files=$(find "$MAIN_SUITE" -name "*.py" -type f 2>/dev/null | wc -l)
total_services=$(systemctl list-unit-files | grep -E "(smartfriend|smartfrind|sf-|ffactory)" | wc -l)
active_services=$(systemctl list-units --all | grep -E "(smartfriend|smartfrind|sf-|ffactory)" | grep "active" | wc -l)

log "الإحصائيات الشاملة:"
log "  📁 مجلدات: $total_dirs"
log "  📄 ملفات: $total_files"
log "  🐍 ملفات Python: $total_py_files"
log "  ⚙️ خدمات مثبتة: $total_services"
log "  🟢 خدمات نشطة: $active_services"

# =============================================================================
# 8. التوصيات والخطوات التالية
# =============================================================================

section "8. 🎯 التوصيات والخطوات التالية"

log "بناءً على الجرد، التوصيات هي:"
log "  ✅ توحيد جميع الخدمات تحت namespace sf-* فقط"
log "  ✅ دمج كود smartfrind/ في smartfriend/app/"
log "  ✅ إيقاف وتعطيل خدمات smartfrind-* و smartfriend-*"
log "  ✅ الحفاظ على FFactory كمنتج مستقل"
log "  ✅ توحيد قواعد البيانات تحت var/db/"
log "  ✅ توحيد السجلات تحت var/logs/"

log "🎉 اكتمل الجرد الشامل للمشروع!"
log "📋 التقرير الكامل: $REPORT"

echo -e "\n🎯 الخطوات التالية المقترحة:"
echo "1. مراجعة التقرير لفهم المشروع بالكامل"
echo "2. تحديد الوظائف المكررة للتخلص منها" 
echo "3. توحيد الخدمات تحت أسماء sf- فقط"
echo "4. دمج الكود في smartfriend/app/"
echo "5. الحفاظ على FFactory كمنتج مستقل"


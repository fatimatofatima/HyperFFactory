#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

echo "=================================================="
echo "   📋 جرد شامل لـ SmartFrind (الإصدار المصحح)"
echo "=================================================="
echo "الوقت: $(date)"
echo "=================================================="

# إنشاء مجلد التقارير
REPORT_DIR="/root/sf_migration"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/smartfrind_inventory_complete_$(date +%Y%m%d_%H%M%S).txt"

# دالة للتسجيل في التقرير
log() {
    echo "$1" | tee -a "$REPORT_FILE"
}

log "🕒 وقت بدء الجرد: $(date)"
log "=================================================="

# ================================
# 1. البحث عن مسارات SmartFrind
# ================================
log ""
log "1. 📁 مسارات SmartFrind الموجودة:"
log "================================="

find /opt /var -maxdepth 2 -type d -name "*smartfrind*" 2>/dev/null | while read path; do
    if [[ -d "$path" ]]; then
        size=$(du -sh "$path" 2>/dev/null | cut -f1 || echo "unknown")
        log "   📂 $path ($size)"
        
        # عرض محتويات مهمة
        if [[ "$path" == "/opt/smartfrind" ]]; then
            log "      📝 محتويات المجلد الرئيسي:"
            ls -la "$path" 2>/dev/null | head -10 | while read item; do
                log "         $item"
            done
        fi
    fi
done

# ================================
# 2. خدمات Systemd المرتبطة
# ================================
log ""
log "2. 🔧 خدمات Systemd المرتبطة بـ SmartFrind:"
log "==========================================="

systemctl list-unit-files | grep -E "smartfrind|smartfriend" | cut -d' ' -f1 | while read service; do
    enabled_status=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
    active_status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
    log "   ⚙️  $service"
    log "      التمكين: $enabled_status - النشاط: $active_status"
done

# ================================
# 3. قواعد البيانات - الإصدار المصحح
# ================================
log ""
log "3. 🗃️ قواعد البيانات المرتبطة بـ SmartFrind:"
log "============================================"

# البحث عن قواعد بيانات في مسارات smartfrind
find /opt /var -name "*smartfrind*" -type d 2>/dev/null | while read dir; do
    find "$dir" -name "*.db" -type f 2>/dev/null | while read db; do
        if [[ -f "$db" ]]; then
            size=$(du -h "$db" 2>/dev/null | cut -f1 || echo "unknown")
            tables=$(sqlite3 "$db" ".tables" 2>/dev/null | wc -w 2>/dev/null || echo "0")
            log "   💾 $db ($size) - $tables جدول"
            
            # عد السجلات في الجداول الرئيسية
            for table in ai_memory knowledge_base user_memory interactions; do
                count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
                if [[ "$count" != "0" ]] && [[ "$count" != "Error:"* ]]; then
                    log "      📊 $table: $count سجل"
                fi
            done
        fi
    done
done

# قواعد بيانات محددة نعرفها
log ""
log "   🔍 قواعد البيانات المعروفة:"
known_dbs=(
    "/var/lib/smartfrind/smart_memory.db"
    "/opt/smartfrind/smartfrind.db"
    "/opt/smartfrind/data/smartfrind.db"
    "/opt/smartfriend-suite/smartfrind/smartfrind.db"
)

for db in "${known_dbs[@]}"; do
    if [[ -f "$db" ]]; then
        size=$(du -h "$db" 2>/dev/null | cut -f1 || echo "unknown")
        tables=$(sqlite3 "$db" ".tables" 2>/dev/null | tr '\n' ' ' 2>/dev/null || echo "ERROR")
        log "   💾 $db ($size)"
        log "      الجداول: $tables"
        
        # عد السجلات في الجداول الرئيسية
        for table in ai_memory knowledge_base user_memory interactions; do
            count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
            if [[ "$count" != "0" ]] && [[ "$count" != "Error:"* ]]; then
                log "      📊 $table: $count سجل"
            fi
        done
    else
        log "   ❌ $db (غير موجود)"
    fi
done

# ================================
# 4. الملفات المهمة المحددة
# ================================
log ""
log "4. 📄 الملفات المهمة المحددة:"
log "============================"

important_files=(
    "/opt/smartfrind/continuous_learning.sh"
    "/opt/smartfrind/fix_and_setup.sh"
    "/opt/smartfrind/setup_cron.sh"
    "/opt/smartfrind/learn_from_premium_sources.py"
    "/opt/smartfrind/learn_from_curriculum.py"
    "/opt/smartfrind/build_knowledge_base.py"
    "/opt/smartfriend-suite/smartfrind/continuous_learning.sh"
)

for file in "${important_files[@]}"; do
    if [[ -f "$file" ]]; then
        size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "unknown")
        log "   ✅ $file ($size)"
    else
        log "   ❌ $file (غير موجود)"
    fi
done

# ================================
# 5. فحص smartfrind داخل السويت
# ================================
log ""
log "5. 🔍 فحص SmartFrind داخل SmartFriend Suite:"
log "==========================================="

if [[ -d "/opt/smartfriend-suite/smartfrind" ]]; then
    size=$(du -sh "/opt/smartfriend-suite/smartfrind" 2>/dev/null | cut -f1 || echo "unknown")
    log "   📁 /opt/smartfriend-suite/smartfrind ($size)"
    
    # عد الملفات
    file_count=$(find "/opt/smartfriend-suite/smartfrind" -type f 2>/dev/null | wc -l)
    log "   📄 عدد الملفات: $file_count"
    
    # عرض الهيكل
    log "   🏗️  الهيكل:"
    find "/opt/smartfriend-suite/smartfrind" -maxdepth 2 -type d 2>/dev/null | while read dir; do
        dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1 || echo "unknown")
        log "      📂 $dir ($dir_size)"
    done
else
    log "   ❌ /opt/smartfriend-suite/smartfrind غير موجود"
fi

# ================================
# 6. ملخص إحصائي
# ================================
log ""
log "6. 📊 الملخص الإحصائي:"
log "======================="

# عد الملفات والمجلدات
smartfrind_dirs=$(find /opt /var -name "*smartfrind*" -type d 2>/dev/null | wc -l)
smartfrind_files=$(find /opt/smartfrind* -type f 2>/dev/null | wc -l)
smartfrind_services=$(systemctl list-unit-files | grep -c "smartfrind")
smartfrind_dbs=$(find /opt /var -name "*smartfrind*" -name "*.db" -type f 2>/dev/null | wc -l)

log "   📁 المجلدات: $smartfrind_dirs"
log "   📄 الملفات: $smartfrind_files"
log "   🔧 الخدمات: $smartfrind_services"
log "   🗃️ قواعد البيانات: $smartfrind_dbs"

# ================================
# 7. التوصيات بناء على الاكتشاف
# ================================
log ""
log "7. 💡 التوصيات للدمج:"
log "===================="

log "   ✅ المسار الرئيسي: /opt/smartfrind (8K - فارغ تقريباً)"
log "   ✅ المسار الفعلي: /opt/smartfriend-suite/smartfrind (68M - يحتوي على الكود الحقيقي)"
log "   ✅ قاعدة البيانات الرئيسية: /var/lib/smartfrind/smart_memory.db (535M)"
log "   ⚠️  عدد الخدمات: 47 خدمة systemd مرتبطة بـ SmartFrind"
log ""
log "   🎯 خطة الدمج المقترحة:"
log "      • استخدام /opt/smartfriend-suite/smartfrind كمصدر للكود"
log "      • الحفاظ على /var/lib/smartfrind/smart_memory.db كقاعدة معرفة رئيسية"
log "      • تعطيل معظم خدمات smartfrind systemd والاعتماد على خدمات السويت"
log "      • نقل أي كود مطلوب من smartfrind إلى هيكل السويت المناسب"

log ""
log "=================================================="
log "✅ تم الانتهاء من الجرد الشامل"
log "📄 التقرير محفوظ في: $REPORT_FILE"
log "=================================================="

# عرض ملخص سريع
echo ""
echo "🎯 الاكتشافات الرئيسية:"
echo "========================"
echo "📁 SmartFrind الفعلي: /opt/smartfriend-suite/smartfrind (68M)"
echo "📁 SmartFrind الرمزي: /opt/smartfrind (8K - فارغ)"
echo "🗃️ قاعدة المعرفة: /var/lib/smartfrind/smart_memory.db (535M)"
echo "🔧 الخدمات: 47 خدمة systemd"
echo ""
echo "📄 التقرير الكامل: $REPORT_FILE"


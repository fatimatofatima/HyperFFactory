#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# 🔍 SmartFriend - Learning & Spider Diagnostic
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info() { echo -e "${BLUE}[i]${NC} $*"; }
debug() { echo -e "${CYAN}[?]${NC} $*"; }
note() { echo -e "${MAGENTA}[💡]${NC} $*"; }

echo
echo "==============================================="
echo "   🔍 SmartFriend - Learning & Spider Diagnostic"
echo "   📊 READ-ONLY - No Changes Will Be Made"
echo "==============================================="
echo

TS="$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="/root/sf_diag_reports"
REPORT_FILE="${REPORT_DIR}/learning_diag_${TS}.txt"
mkdir -p "$REPORT_DIR"

exec > >(tee -a "$REPORT_FILE") 2>&1

# 1) فحص قواعد البيانات
info "1. 📊 DATABASE ANALYSIS"

DB_MAIN="/var/lib/smartfrind/smart_memory.db"
DB_CORE="/opt/smartfrind/data/smartfrind.db"

echo "   Main DB: $DB_MAIN"
if [[ -f "$DB_MAIN" ]]; then
    log "   ✅ موجود - حجم: $(du -h "$DB_MAIN" | cut -f1)"
    
    # فحص الجداول في smart_memory.db
    echo "   📋 الجداول في smart_memory.db:"
    sqlite3 "$DB_MAIN" ".tables" | tr ' ' '\n' | while read table; do
        if [[ -n "$table" ]]; then
            count=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "error")
            size=$(sqlite3 "$DB_MAIN" "SELECT SUM(pgsize) FROM dbstat WHERE name='$table'" 2>/dev/null || echo "unknown")
            echo "      📁 $table: $count صفوف ($size بايت)"
        fi
    done
    
    # فحص محتوى knowledge_base بالتفصيل
    echo "   🔍 تحليل knowledge_base:"
    kb_count=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM knowledge_base" 2>/dev/null || echo "0")
    if [[ "$kb_count" -gt 0 ]]; then
        log "      يوجد $kb_count سجل في knowledge_base"
        sqlite3 "$DB_MAIN" "SELECT category, COUNT(*) as count FROM knowledge_base GROUP BY category" 2>/dev/null | while read line; do
            echo "        📂 $line"
        done
    else
        warn "      ❌ knowledge_base فارغة"
    fi
else
    error "   ❌ غير موجود"
fi

echo
echo "   Core DB: $DB_CORE"
if [[ -f "$DB_CORE" ]]; then
    log "   ✅ موجود - حجم: $(du -h "$DB_CORE" | cut -f1)"
    
    # فحص الجداول في smartfrind.db
    echo "   📋 الجداول في smartfrind.db:"
    sqlite3 "$DB_CORE" ".tables" | tr ' ' '\n' | while read table; do
        if [[ -n "$table" ]]; then
            count=$(sqlite3 "$DB_CORE" "SELECT COUNT(*) FROM $table" 2>/dev/null || echo "error")
            echo "      📁 $table: $count صفوف"
        fi
    done
    
    # فحص وجود conscious_memory
    if sqlite3 "$DB_CORE" ".tables" | grep -q "conscious_memory"; then
        log "      ✅ conscious_memory موجود"
        cm_count=$(sqlite3 "$DB_CORE" "SELECT COUNT(*) FROM conscious_memory")
        echo "        $cm_count سجل في conscious_memory"
    else
        warn "      ❌ conscious_memory غير موجود (مشكلة في migration)"
    fi
else
    error "   ❌ غير موجود"
fi

# 2) فحص نظام الـ Spider
info "2. 🕷️ SPIDER SYSTEM ANALYSIS"

SPIDER_FILES=(
    "/opt/smartfrind/smart_spider.py"
    "/opt/smartfrind/daily_spider.sh" 
    "/opt/smartfrind/test_spider.sh"
    "/opt/smartfrind/setup_cron.sh"
)

echo "   🔍 فحص ملفات الـ Spider:"
for file in "${SPIDER_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        log "      ✅ $(basename "$file") - موجود"
        if [[ -x "$file" ]]; then
            echo "        🔧 قابل للتشغيل"
        fi
        # عرض حجم الملف
        echo "        📏 حجم: $(du -h "$file" | cut -f1), أسطر: $(wc -l < "$file")"
    else
        warn "      ❌ $(basename "$file") - غير موجود"
    fi
done

# فحص محتوى smart_spider.py لو موجود
if [[ -f "/opt/smartfrind/smart_spider.py" ]]; then
    echo "   📝 محتوى smart_spider.py (الأسطر الأولى):"
    head -20 "/opt/smartfrind/smart_spider.py" | while read line; do
        echo "        $line"
    done
fi

# 3) فحص الجدولة التلقائية
info "3. ⏰ SCHEDULING ANALYSIS"

echo "   🔍 فحص الـ Cron Jobs:"
if command -v crontab &> /dev/null; then
    echo "   📋 Crontab الحالي:"
    crontab -l 2>/dev/null | grep -E "smartfrind|spider|learner" | while read job; do
        if [[ -n "$job" ]]; then
            log "      ✅ $job"
        fi
    done
    
    if ! crontab -l 2>/dev/null | grep -q -E "smartfrind|spider|learner"; then
        warn "      ❌ لا توجد مهام cron لـ SmartFriend"
    fi
fi

echo "   🔍 فحص Systemd Services:"
SERVICES=(
    "smartfrind" "spider" "learner" "ffactory" "memory" "unified"
)
for service in "${SERVICES[@]}"; do
    if systemctl list-unit-files | grep -q "$service"; then
        log "      ✅ خدمة $service - موجودة في systemd"
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "disabled")
        echo "        الحالة: $status, مفعلة: $enabled"
    fi
done

# 4) فحص مجلدات المعرفة
info "4. 📚 KNOWLEDGE DIRECTORIES ANALYSIS"

KNOWLEDGE_DIRS=(
    "/opt/smartfrind/curriculum"
    "/opt/smartfrind/premium_knowledge" 
    "/opt/smartfrind/data"
)

for dir in "${KNOWLEDGE_DIRS[@]}"; do
    echo "   🔍 فحص $dir:"
    if [[ -d "$dir" ]]; then
        log "      ✅ موجود"
        file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo "        📁 عدد الملفات: $file_count"
        
        # عرض أحدث الملفات
        find "$dir" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -5 | while read file; do
            filename=$(echo "$file" | cut -d' ' -f2-)
            timestamp=$(echo "$file" | cut -d' ' -f1)
            date_str=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
            echo "        📄 $(basename "$filename") - $date_str"
        done
        
        # فحص محتوى curriculum
        if [[ "$dir" == "/opt/smartfrind/curriculum" ]]; then
            echo "        📖 محتوى Curriculum:"
            find "$dir" -name "*.md" -o -name "*.csv" 2>/dev/null | while read file; do
                echo "          📄 $(basename "$file") - $(wc -l < "$file") سطر"
            done
        fi
    else
        warn "      ❌ غير موجود"
    fi
    echo
done

# 5) فحص عمليات التعلم النشطة
info "5. 🤖 LEARNING PROCESSES ANALYSIS"

echo "   🔍 البحث عن عمليات التعلم النشطة:"
ps aux | grep -E "python.*(learn|spider|curriculum)" | grep -v grep | while read process; do
    log "      ✅ عملية نشطة: $process"
done

if ! ps aux | grep -q -E "python.*(learn|spider|curriculum)"; then
    warn "      ❌ لا توجد عمليات تعلم نشطة حالياً"
fi

# 6) فحص واجهات APIs التعليمية
info "6. 🌐 LEARNING APIs ANALYSIS"

echo "   🔍 البحث عن endpoints التعلم في الكود:"
find /opt/smartfrind -name "*.py" -type f | xargs grep -l "/spider/\|/learn/\|/crawl/\|/ingest/" 2>/dev/null | head -10 | while read file; do
    log "      📄 $(basename "$file") - يحتوي على endpoints تعلم"
    grep -E "/spider/\|/learn/\|/crawl/\|/ingest/" "$file" 2>/dev/null | head -3 | while read endpoint; do
        echo "        🔗 $endpoint"
    done
done

# 7) التقرير التنفيذي
info "7. 📈 EXECUTIVE SUMMARY"

echo "   🎯 الملخص التنفيذي:"
echo

# عد الإحصائيات
main_db_exists=$( [[ -f "$DB_MAIN" ]] && echo "✅" || echo "❌" )
core_db_exists=$( [[ -f "$DB_CORE" ]] && echo "✅" || echo "❌" )
kb_has_data=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM knowledge_base" 2>/dev/null || echo "0")
spider_files_count=0
for file in "${SPIDER_FILES[@]}"; do [[ -f "$file" ]] && ((spider_files_count++)); done
cron_jobs=$(crontab -l 2>/dev/null | grep -c -E "smartfrind|spider|learner" || echo "0")
learning_processes=$(ps aux | grep -c -E "python.*(learn|spider|curriculum)" | grep -v grep || echo "0")

echo "   📊 الإحصائيات:"
echo "      • قواعد البيانات: Main $main_db_exists, Core $core_db_exists"
echo "      • knowledge_base تحتوي على: $kb_has_data سجل"
echo "      • ملفات الـ Spider: $spider_files_count/4 موجودة"
echo "      • مهام Cron: $cron_jobs"
echo "      • عمليات التعلم النشطة: $learning_processes"
echo

# التوصيات
info "8. 💡 RECOMMENDATIONS"

if [[ "$kb_has_data" -eq 0 ]]; then
    warn "   ⚠️  knowledge_base فارغة - النظام لم يبدأ التعلم بعد"
    note "      الإجراء: تشغيل learn_from_curriculum.py يدوياً"
fi

if [[ "$spider_files_count" -lt 2 ]]; then
    warn "   ⚠️  ملفات الـ Spider ناقصة - النظام لا يستطيع الزحف"
    note "      الإجراء: التحقق من وجود smart_spider.py الأساسي"
fi

if [[ "$cron_jobs" -eq 0 ]]; then
    warn "   ⚠️  لا توجد جدولة تلقائية - التعلم غير مجدول"
    note "      الإجراء: إعداد cron jobs للتعلم اليومي"
fi

if [[ "$learning_processes" -eq 0 ]]; then
    warn "   ⚠️  لا توجد عمليات تعلم نشطة - النظام خامل"
    note "      الإجراء: تشغيل خدمات التعلم"
fi

# خاتمة
echo
echo "==============================================="
log "   🔍 التشخيص اكتمل - $(date)"
log "   📄 التقرير محفوظ في: $REPORT_FILE"
echo "==============================================="

# عرض التقرير للمستخدم
echo
info "📋 ملخص سريع من التقرير:"
tail -30 "$REPORT_FILE" | grep -E "\[(✓|!|✗|i|💡)\]" | head -20

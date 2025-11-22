#!/usr/bin/env bash
set -Eeuo pipefail

echo "=================================================="
echo "   📊 التقرير الشامل - SmartFriend Suite Audit"
echo "   🕐 $(date)"
echo "=================================================="
echo

DB_MAIN="/var/lib/smartfrind/smart_memory.db"
SUITE_DIR="/opt/smartfriend-suite"
SMARTFRIND_DIR="/opt/smartfrind"

# الألوان
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[ℹ]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[⚠]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

# 1) فحص قواعد البيانات
echo "1. 🗄️  قواعد البيانات"
echo "----------------------------------------"

if [[ -f "$DB_MAIN" ]]; then
    info "المسار: $DB_MAIN"
    echo "   📏 الحجم: $(du -h "$DB_MAIN" | cut -f1)"
    
    # إحصائيات ai_memory
    ai_total=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM ai_memory;" 2>/dev/null || echo "0")
    ai_with_data=$(sqlite3 "$DB_MAIN" "
        SELECT COUNT(*) FROM ai_memory 
        WHERE (user_input IS NOT NULL AND user_input != '')
           OR (ai_response IS NOT NULL AND ai_response != '')
           OR (question IS NOT NULL AND question != '')
           OR (answer IS NOT NULL AND answer != '')
    " 2>/dev/null || echo "0")
    
    echo "   🤖 ai_memory: $ai_total سجل"
    echo "   💾 بها بيانات: $ai_with_data سجل"
    echo "   🗑️  فارغة: $((ai_total - ai_with_data)) سجل"
    
    # إحصائيات knowledge_base
    kb_total=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM knowledge_base;" 2>/dev/null || echo "0")
    echo "   📚 knowledge_base: $kb_total سجل"
    
    # إحصائيات FTS
    fts_total=$(sqlite3 "$DB_MAIN" "SELECT COUNT(*) FROM ai_memory_fts;" 2>/dev/null || echo "0")
    echo "   🔍 FTS Index: $fts_total سجل"
    
    if [[ $kb_total -gt 100 ]]; then
        success "قاعدة المعرفة جيدة ($kb_total سجل)"
    elif [[ $kb_total -gt 0 ]]; then
        warning "قاعدة المعرفة ضعيفة ($kb_total سجل)"
    else
        error "قاعدة المعرفة فارغة"
    fi
    
else
    error "قاعدة البيانات الرئيسية غير موجودة"
fi

echo

# 2) فحص الهيكل الفعلي لـ ai_memory
echo "2. 🔧 هيكل ai_memory الفعلي"
echo "----------------------------------------"

if [[ -f "$DB_MAIN" ]]; then
    sqlite3 "$DB_MAIN" "PRAGMA table_info(ai_memory);" 2>/dev/null | while IFS='|' read -r cid name type notnull dflt_value pk; do
        echo "   📋 $name ($type)"
    done
    
    # فحص البيانات الفعلية
    echo
    info "عينة من البيانات الفعلية:"
    sqlite3 "$DB_MAIN" "
        SELECT 
            rowid,
            category,
            CASE 
                WHEN user_input IS NOT NULL AND user_input != '' THEN substr(user_input, 1, 40)
                WHEN question IS NOT NULL AND question != '' THEN substr(question, 1, 40)
                ELSE '---'
            END as preview
        FROM ai_memory 
        WHERE (user_input IS NOT NULL AND user_input != '')
           OR (question IS NOT NULL AND question != '')
        LIMIT 5;
    " 2>/dev/null | while IFS='|' read -r rowid category preview; do
        echo "   📝 [$rowid] $category: $preview..."
    done
fi

echo

# 3) فحص أنظمة التعلم في السويت
echo "3. 🧠 أنظمة التعلم في SmartFriend Suite"
echo "----------------------------------------"

LEARNING_SYSTEMS=(
    "bots/learn_from_curriculum.py"
    "bots/build_knowledge_base.py"
    "bots/learn_from_premium_sources.py"
    "bots/process_sources.py"
    "packages/ingest/spider_core.py"
    "bots/smart_spider.py"
    "bots/quick_spider.py"
)

for system in "${LEARNING_SYSTEMS[@]}"; do
    if [[ -f "$SUITE_DIR/$system" ]]; then
        size=$(wc -l < "$SUITE_DIR/$system" 2>/dev/null || echo "0")
        if [[ $size -gt 10 ]]; then
            success "$system ($size سطر)"
        else
            warning "$system ($size سطر - صغير)"
        fi
    else
        error "$system (غير موجود)"
    fi
done

echo

# 4) فحص البوابات والخدمات
echo "4. 🌐 البوابات والخدمات النشطة"
echo "----------------------------------------"

info "الخدمات الجارية:"
ps aux | grep -E "(uvicorn|python.*smart)" | grep -v grep | head -5 | while read line; do
    pid=$(echo $line | awk '{print $2}')
    cmd=$(echo $line | awk '{for(i=11;i<=NF;i++) printf $i " "; print ""}' | cut -c1-60)
    echo "   🔄 PID $pid: $cmd"
done

# فحص منافذ الـ API
info "المنافذ المستخدمة:"
netstat -tlnp 2>/dev/null | grep -E ":(8211|8214|8170|8220)" | while read line; do
    echo "   🔌 $line"
done || echo "   ℹ️  لا توجد منافذ API نشطة"

echo

# 5) فحص الملفات المندمجة
echo "5. 📦 الملفات المندمجة من SmartFrind"
echo "----------------------------------------"

LEGACY_DIR="$SUITE_DIR/legacy_integration"
if [[ -d "$LEGACY_DIR" ]]; then
    info "مجلد الدمج: $LEGACY_DIR"
    
    for category in learning_systems memory_systems gateways tools; do
        dir_path="$LEGACY_DIR/$category"
        if [[ -d "$dir_path" ]]; then
            count=$(find "$dir_path" -name "*.py" -type f | wc -l)
            case $category in
                "learning_systems") name="أنظمة التعلم" ;;
                "memory_systems") name="أنظمة الذاكرة" ;;
                "gateways") name="البوابات" ;;
                "tools") name="الأدوات" ;;
            esac
            echo "   📁 $name: $count ملف"
        fi
    done
else
    warning "مجلد الدمج غير موجود"
fi

echo

# 6) فحص الـ Dependencies
echo "6. 📦 الـ Dependencies المثبتة"
echo "----------------------------------------"

PYTHON_DEPS=("aiohttp" "fastapi" "uvicorn" "requests" "beautifulsoup4" "sqlite3")

for dep in "${PYTHON_DEPS[@]}"; do
    if python3 -c "import $dep" 2>/dev/null; then
        success "$dep (مثبت)"
    else
        error "$dep (غير مثبت)"
    fi
done

echo

# 7) فحص الـ Spider System
echo "7. 🕷️  نظام الزحف (Spider)"
echo "----------------------------------------"

# فحص ملفات التكوين
SPIDER_CONFIGS=(
    "bots/seeds.txt"
    "bots/allowlist_domains.txt" 
    "bots/denylist_patterns.txt"
    "ops/spider_config.yaml"
)

for config in "${SPIDER_CONFIGS[@]}"; do
    if [[ -f "$SUITE_DIR/$config" ]]; then
        lines=$(wc -l < "$SUITE_DIR/$config" 2>/dev/null || echo "0")
        success "$config ($lines سطر)"
    else
        warning "$config (غير موجود)"
    fi
done

# فحص آخر تشغيل للـ Spider
info "آخر تشغيل للـ Spider:"
find /var/log/smartfrind -name "*spider*" -o -name "*crawl*" 2>/dev/null | head -3 | while read log; do
    if [[ -f "$log" ]]; then
        last_modified=$(stat -c %y "$log" 2>/dev/null | cut -d' ' -f1)
        size=$(du -h "$log" | cut -f1)
        echo "   📄 $(basename "$log") - $last_modified ($size)"
    fi
done

echo

# 8) التوصيات
echo "8. 💡 التوصيات والحالة العامة"
echo "----------------------------------------"

# تحليل الحالة العامة
if [[ $kb_total -gt 200 && $ai_with_data -gt 500 ]]; then
    success "الحالة: ممتازة ✅"
    echo "   • قاعدة المعرفة غنية ($kb_total سجل)"
    echo "   • الذاكرة نشطة ($ai_with_data سجل مفيد)"
    echo "   • النظام جاهز للاستخدام الكامل"
elif [[ $kb_total -gt 50 && $ai_with_data -gt 100 ]]; then
    warning "الحالة: جيدة ⚠️"
    echo "   • قاعدة المعرفة مقبولة ($kb_total سجل)"
    echo "   • تحتاج إلى مزيد من التعلم"
    echo "   • يمكن تشغيل أنظمة التعلم الإضافية"
else
    error "الحالة: تحتاج تحسين ❌"
    echo "   • قاعدة المعرفة ضعيفة ($kb_total سجل)"
    echo "   • البيانات الفعلية قليلة ($ai_with_data سجل)"
    echo "   • يلزم تشغيل عمليات التعلم والزحف"
fi

# توصيات محددة
echo
info "التوصيات:"
if [[ $kb_total -lt 100 ]]; then
    echo "   📚 تشغيل learn_from_curriculum.py لبناء المعرفة"
fi
if [[ $ai_with_data -lt 200 ]]; then
    echo "   🕷️  تشغيل smart_spider.py لجمع المزيد من البيانات"
fi
if ! python3 -c "import aiohttp" 2>/dev/null; then
    echo "   📦 تثبيت aiohref: pip3 install aiohttp"
fi

echo
echo "=================================================="
echo "   🎯 التقرير اكتمل - $(date)"
echo "=================================================="

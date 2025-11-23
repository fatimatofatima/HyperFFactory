#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
REPORT_FILE="$REPORT_DIR/hf_scripts_catalog_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$REPORT_DIR"

echo "🔍 بدء مسح السكريبتات في HyperFFactory..."
echo "⏰ الوقت: $(date)"
echo "=================================================="

# دالة لتصنيف السكريبتات
classify_script() {
    local script="$1"
    local name=$(basename "$script")
    
    case "$name" in
        *learn*|*memory*|*knowledge*|*train*)
            echo "🧠 التعلم والذاكرة"
            ;;
        *worker*|*operation*|*manage*|*control*)
            echo "⚙️ العمليات التشغيلية"
            ;;
        *solo*|*isolation*|*alone*)
            echo "🔄 الوحدة والعزلة"
            ;;
        *inspect*|*test*|*check*|*analyze*)
            echo "🔍 الفحص والاختبار"
            ;;
        *health*|*monitor*)
            echo "❤️ الصحة والمراقبة"
            ;;
        *report*|*stats*|*analytics*)
            echo "📊 التقارير والإحصائيات"
            ;;
        *security*|*guard*|*secure*)
            echo "🔒 الأمان والحماية"
            ;;
        *agent*|*ai*|*smart*)
            echo "🤖 الذكاء الاصطناعي والوكلاء"
            ;;
        *db*|*database*|*migrate*|*seed*)
            echo "🗄️ قواعد البيانات والهجرة"
            ;;
        *init*|*setup*|*config*)
            echo "🛠️ التهيئة والإعداد"
            ;;
        *backup*|*clean*|*maintenance*)
            echo "🧹 الصيانة والنسخ الاحتياطي"
            ;;
        *)
            echo "📁 أخرى"
            ;;
    esac
}

# مسح المجلدات الرئيسية
SCAN_PATHS=(
    "/root/HyperFFactory"
    "/opt/smartfriend-suite" 
    "/opt/ffactory"
)

declare -A categories

echo "📁 قائمة السكريبتات المصنفة:"
echo "=================================================="

for path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        echo ""
        echo "📍 المسار: $path"
        echo "--------------------------------------------------"
        
        # البحث عن الملفات القابلة للتنفيذ أو بامتدادات السكريبتات
        while IFS= read -r -d '' script; do
            if [[ -f "$script" && ( -x "$script" || "$script" =~ \.(sh|py|bash)$ ) ]]; then
                category=$(classify_script "$script")
                relative_script=${script#$path/}
                
                echo "  📄 $relative_script"
                echo "     🏷️  $category"
                echo ""
                
                # تخزين للإحصائيات
                categories["$category"]=$((categories["$category"] + 1))
            fi
        done < <(find "$path" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.bash" \) -print0 2>/dev/null)
    else
        echo "⚠️  المسار غير موجود: $path"
    fi
done

# عرض الإحصائيات
echo ""
echo "📊 إحصائيات التصنيف:"
echo "=================================================="
for category in "${!categories[@]}"; do
    count=${categories["$category"]}
    printf "  %-25s: %2d سكريبت\\n" "$category" "$count"
done

# حفظ التقرير
{
    echo "📋 تقرير سكريبتات HyperFFactory"
    echo "⏰ الوقت: $(date)"
    echo "=================================================="
    echo ""
    
    for path in "${SCAN_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            echo "📍 المسار: $path"
            echo "--------------------------------------------------"
            
            while IFS= read -r -d '' script; do
                if [[ -f "$script" && ( -x "$script" || "$script" =~ \.(sh|py|bash)$ ) ]]; then
                    category=$(classify_script "$script")
                    relative_script=${script#$path/}
                    echo "📄 $relative_script"
                    echo "   🏷️  $category"
                fi
            done < <(find "$path" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.bash" \) -print0 2>/dev/null)
            echo ""
        fi
    done
    
    echo "📊 الإحصائيات:"
    echo "--------------------------------------------------"
    for category in "${!categories[@]}"; do
        count=${categories["$category"]}
        printf "%-25s: %2d سكريبت\\n" "$category" "$count"
    done
} > "$REPORT_FILE"

echo ""
echo "✅ تم إنشاء التقرير: $REPORT_FILE"
echo "🔍 إجمالي السكريبتات الممسوحة: $(find "${SCAN_PATHS[@]}" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.bash" \) 2>/dev/null | wc -l)"


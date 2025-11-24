#!/bin/bash
echo "🧠 عارض ملفات ذكي - 6 أنوية + تصفية الضوضاء"
echo "==========================================="

# إعدادات متقدمة
FILTER_PATTERNS=(
    "*.pyc" "*.pyo" "__pycache__" "*.egg-info" "*.so" "*.dll"
    "node_modules" ".git" ".svn" ".DS_Store" "Thumbs.db"
    "*.log" "*.tmp" "*.temp" "*.swp" "*.swo"
    "venv" ".virtualenv" ".env" ".conda"
    ".cache" ".npm" ".yarn" "cache" "tmp"
)

# دالة تصفية ذكية
smart_filter() {
    local file="$1"
    local name=$(basename "$file")
    
    # تجاهل أنماط الضوضاء
    for pattern in "${FILTER_PATTERNS[@]}"; do
        if [[ "$name" == $pattern || "$file" == *"/$pattern"* ]]; then
            return 1
        fi
    done
    
    # تجاهل الملفات المخفية (ما عدا .hyperfactory)
    if [[ "$name" == .* && "$name" != ".hyperfactory"* ]]; then
        return 1
    fi
    
    return 0
}

# إحصائيات متقدمة بـ 6 أنوية
advanced_stats() {
    local dir="${1:-.}"
    
    echo "🔍 جمع الإحصائيات (6 أنوية)..."
    
    # استخدام parallel لمعالجة سريعة
    stats=$(find "$dir" -type f 2>/dev/null | \
    parallel -j6 --halt soon,fail=1 '
        file={}
        '"$(declare -f smart_filter)"'
        if smart_filter "$file"; then
            ext="${file##*.}"
            case "$ext" in
                py) echo "PYTHON" ;;
                sh) echo "SHELL" ;;
                json|yaml|yml) echo "CONFIG" ;;
                db|sqlite) echo "DATABASE" ;;
                md|txt) echo "DOCS" ;;
                js|ts) echo "WEB" ;;
                java|scala) echo "JVM" ;;
                c|cpp|h) echo "CPP" ;;
                go) echo "GO" ;;
                rs) echo "RUST" ;;
                *) echo "OTHER" ;;
            esac
        fi
    ' | sort | uniq -c | sort -nr)
    
    echo "$stats"
}

# عرض الملفات المهمة فقط
show_important_files() {
    local dir="${1:-.}"
    
    echo "📁 الملفات المهمة (مستبعدة الضوضاء):"
    echo "====================================="
    
    # Python files (مهمة فقط)
    echo "🐍 Python المهم:"
    find "$dir" -name "*.py" -type f 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            # تجاهل ملفات الاختبار والمكتبات
            if [[ ! "$file" =~ (test_|_test|/tests/|/venv/|/site-packages/) ]]; then
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                if [ "$size" -gt 100 ]; then  # تجاهل الملفات الصغيرة جداً
                    echo "  📄 $file ($(numfmt --to=iec "$size"))"
                fi
            fi
        fi
    done | head -10
    
    # Shell scripts (مهمة فقط)
    echo ""
    echo "🐚 Shell المهم:"
    find "$dir" -name "*.sh" -type f 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            if [[ ! "$file" =~ (/\.?cache/|/tmp/|/temp/) ]]; then
                echo "  ⚡ $file"
            fi
        fi
    done | head -10
    
    # Configuration files
    echo ""
    echo "⚙️  التكوينات:"
    find "$dir" \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) -type f 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            if [[ "$file" =~ (config|setting|docker-compose) ]]; then
                echo "  🔧 $file"
            fi
        fi
    done | head -10
}

# تحليل المشاريع
analyze_projects() {
    local dir="${1:-.}"
    
    echo "🏗️  تحليل المشاريع:"
    echo "=================="
    
    # البحث عن مشاريع Python
    find "$dir" -name "requirements.txt" -o -name "setup.py" -o -name "pyproject.toml" 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            project_dir=$(dirname "$file")
            echo "  🐍 Python Project: $project_dir"
        fi
    done | head -5
    
    # البحث عن مشاريع Node.js
    find "$dir" -name "package.json" 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            project_dir=$(dirname "$file")
            echo "  📦 Node.js Project: $project_dir"
        fi
    done | head -5
    
    # البحث عن مشاريع Docker
    find "$dir" -name "Dockerfile" -o -name "docker-compose*.yml" 2>/dev/null | \
    while read file; do
        if smart_filter "$file"; then
            project_dir=$(dirname "$file")
            echo "  🐳 Docker Project: $project_dir"
        fi
    done | head -5
}

# حجم المشاريع بـ 6 أنوية
project_sizes() {
    local dir="${1:-.}"
    
    echo "📊 أحجام المشاريع (6 أنوية):"
    echo "==========================="
    
    # العثور على المجلدات الرئيسية وحساب أحجامها بالتوازي
    find "$dir" -maxdepth 2 -type d 2>/dev/null | \
    while read subdir; do
        if smart_filter "$subdir"; then
            # تجاهل المجلدات الصغيرة جداً
            size=$(du -s "$subdir" 2>/dev/null | cut -f1)
            if [ "$size" -gt 1000 ]; then  # أكثر من 1MB
                echo "$size $subdir"
            fi
        fi
    done | sort -nr | head -10 | \
    while read size path; do
        human_size=$(numfmt --to=iec "$size")
        echo "  📁 $human_size - $(basename "$path")"
    done
}

# الواجهة الرئيسية
main() {
    local target_dir="${1:-.}"
    
    echo "🎯 المسار المستهدف: $target_dir"
    echo "💾 المساحة الحرة: $(df -h "$target_dir" | awk 'NR==2{print $4}')"
    echo ""
    
    # الإحصائيات المتقدمة
    advanced_stats "$target_dir"
    echo ""
    
    # الملفات المهمة
    show_important_files "$target_dir"
    echo ""
    
    # تحليل المشاريع
    analyze_projects "$target_dir"
    echo ""
    
    # أحجام المشاريع
    project_sizes "$target_dir"
    echo ""
    
    # ملخص
    echo "🎯 ملخص:"
    total_files=$(find "$target_dir" -type f 2>/dev/null | wc -l)
    filtered_files=$(find "$target_dir" -type f 2>/dev/null | while read f; do smart_filter "$f" && echo "$f"; done | wc -l)
    echo "  📈 الملفات الإجمالية: $total_files"
    echo "  🎯 الملفات المهمة: $filtered_files"
    echo "  🗑️  الملفات المستبعدة: $((total_files - filtered_files))"
}

# التشغيل على المسارات المهمة
echo "1. 📁 Hyper Factory المدمج:"
main "/root/hyper-factory-merged"

echo ""
echo "2. 🚀 Hyper Factory النهائي:"
main "/root/hyper-factory"

echo ""
echo "3. 📦 SmartFriend Suite:"
main "/opt/smartfriend-suite"

echo ""
echo "4. 🏭 FFactory:"
main "/opt/ffactory"

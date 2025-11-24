#!/bin/bash

echo "🚀 بدء تنظيم جميع السكريبتات المبعثرة..."

# تعريف التصنيفات
declare -A CATEGORIES=(
    ["suites"]="sf_suite_.*\.sh"
    ["services"]="sf_services_.*\.sh"
    ["agents"]="sf_.*_agent\.sh"
    ["gateways"]="sf_.*gateway\.sh"
    ["spiders"]="sf_.*spider\.sh"
    ["secrets"]="sf_.*secret.*\.sh"
    ["unification"]="sf_.*unif.*\.sh"
    ["reports"]="sf_.*report.*\.sh"
    ["testing"]="sf_test_.*\.sh"
    ["maintenance"]="sf_.*fix.*\.sh|sf_.*repair.*\.sh"
    ["core"]="sf_system_.*\.sh|sf_safe_startup\.sh|sf_smart_monitor\.sh"
)

# دالة التنظيم
organize_scripts() {
    local total_moved=0
    
    for category in "${!CATEGORIES[@]}"; do
        pattern="${CATEGORIES[$category]}"
        echo "📁 معالجة: $category"
        
        # إنشاء المجلد إذا لم يكن موجوداً
        mkdir -p "/root/HyperFFactory/scripts/$category"
        
        # البحث ونقل الملفات
        while IFS= read -r -d '' file; do
            if [[ -f "$file" ]]; then
                filename=$(basename "$file")
                mv "$file" "/root/HyperFFactory/scripts/$category/"
                echo "   ✅ نقل: $filename"
                ((total_moved++))
            fi
        done < <(find /root/HyperFFactory -maxdepth 1 -type f -name "sf_*" -regex ".*/${pattern}" -print0)
    done
    
    echo "🎯 تم نقل $total_moved سكريبت بنجاح!"
}

# تنفيذ التنظيم
organize_scripts

# معالجة الملفات المتبقية
echo "🔍 معالجة الملفات المتبقية..."
find /root/HyperFFactory -maxdepth 1 -type f -name "sf_*.sh" -o -name "sf_*.py" | while read -r file; do
    if [[ -f "$file" ]]; then
        filename=$(basename "$file")
        # تصنيف بناء على الكلمات المفتاحية
        if [[ $filename == *"suite"* ]]; then
            mv "$file" "/root/HyperFFactory/scripts/suites/"
        elif [[ $filename == *"service"* ]]; then
            mv "$file" "/root/HyperFFactory/scripts/services/"
        elif [[ $filename == *"test"* ]]; then
            mv "$file" "/root/HyperFFactory/scripts/testing/"
        elif [[ $filename == *"fix"* || $filename == *"repair"* ]]; then
            mv "$file" "/root/HyperFFactory/scripts/maintenance/"
        else
            mv "$file" "/root/HyperFFactory/scripts/core/"
        fi
        echo "   📦 نقل: $filename"
    fi
done

echo "✅ اكتمل التنظيم!"

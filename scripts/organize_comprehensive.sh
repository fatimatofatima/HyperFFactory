#!/bin/bash

echo "🏭 بدء التنظيم الشامل لسكريبتات HyperFFactory..."
echo "================================================"

# تعريف التصنيفات وأنماطها
declare -A CATEGORY_PATTERNS=(
    ["suites"]="sf_suite_.*\.sh"
    ["services"]="sf_services_.*\.sh"
    ["agents"]="sf_.*agent.*\.sh"
    ["gateways"]="sf_.*gateway.*\.sh" 
    ["spiders"]="sf_.*spider.*\.sh"
    ["secrets"]="sf_.*secret.*\.sh"
    ["unification"]="sf_.*unif.*\.sh"
    ["reports"]="sf_.*report.*\.sh"
    ["testing"]="sf_test_.*\.sh"
    ["maintenance"]="sf_.*fix.*\.sh|sf_.*repair.*\.sh|sf_.*maintenance.*\.sh"
    ["core"]="sf_system_.*\.sh|sf_safe_startup\.sh|sf_smart_monitor\.sh"
)

# إنشاء المجلدات
for category in "${!CATEGORY_PATTERNS[@]}"; do
    mkdir -p "/root/HyperFFactory/scripts/$category"
done

# البحث عن جميع سكريبتات sf_*
echo "🔍 البحث عن السكريبتات المبعثرة..."
find /root/HyperFFactory -type f \( -name "sf_*.sh" -o -name "sf_*.py" \) | while read script; do
    filename=$(basename "$script")
    
    # تخطي الملفات الموجودة بالفعل في scripts/
    if [[ $script == /root/HyperFFactory/scripts/* ]]; then
        continue
    fi
    
    matched=false
    
    for category in "${!CATEGORY_PATTERNS[@]}"; do
        pattern="${CATEGORY_PATTERNS[$category]}"
        if [[ $filename =~ $pattern ]]; then
            echo "📦 نقل $filename إلى $category/"
            mv "$script" "/root/HyperFFactory/scripts/$category/" 2>/dev/null
            matched=true
            break
        fi
    done
    
    if [[ $matched == false ]]; then
        echo "📦 نقل $filename إلى core/"
        mv "$script" "/root/HyperFFactory/scripts/core/" 2>/dev/null
    fi
done

echo "✅ اكتمل التنظيم!"

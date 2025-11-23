#!/usr/bin/env bash
set -euo pipefail

echo "🔍 فحص حالة السكريبتات حسب التصنيف..."
echo "=================================================="

declare -A status_count=([🟢]=0 [🟡]=0 [🔵]=0 [⚫]=0)

# فحص السكريبتات الجذرية
echo "## السكريبتات الجذرية (hyper_* / hf_*)"
echo "--------------------------------------------------"

root_scripts=(
    "bin/hf_guard.sh:🟢"
    "bin/hf_health_all.sh:🟢" 
    "setup_hyper_ffactory.sh:🟢"
    "show_structure.sh:🟢"
    "hyper_collect_all_dbs.sh:🟡"
    "hyper_db_audit_readonly.sh:🟡"
    "hyper_db_safe_backup_from_meta.sh:🟡"
    "hyper_db_usage_from_meta.sh:🟡"
    "hyper_scan_dbs.sh:🟡"
    "hyper_identity_init.sh:🟢"
    "hyper_identity_seed.sh:🟢"
    "hyper_init_brain_and_knowledge.sh:🟡"
    "hyper_init_brain_and_knowledge_v2.sh:🟡"
    "hyper_init_data_home.sh:🟢"
    "hyper_init_runtime_dbs.sh:🟢"
    "hyper_init_workers_tables.sh:🟢"
    "hyper_meta_build_db_meta.sh:🟡"
    "hyper_seed_runtime_from_legacy.sh:🔵"
    "hyper_seed_tasks_basics.sh:🟢"
    "hyper_seed_workers_from_services.sh:🟢"
    "hyper_migrate_identity_from_legacy.sh:🔵"
    "hyper_migrate_knowledge_from_legacy.sh:🔵"
)

for script_info in "${root_scripts[@]}"; do
    script="${script_info%:*}"
    status="${script_info#*:}"
    
    if [[ -f "/root/HyperFFactory/$script" ]]; then
        echo "$status $script - موجود"
    else
        echo "❌ $script - غير موجود"
    fi
    
    status_count["$status"]=$((status_count["$status"] + 1))
done

echo ""
echo "## الفئات المتخصصة (المجلدات)"
echo "--------------------------------------------------"

categories=(
    "scripts/core:🟢"
    "scripts/db:🟢"
    "scripts/health:🟢" 
    "scripts/maintenance:🟡"
    "scripts/fix:🟡"
    "scripts/deploy:🟡"
    "scripts/services:🟢"
    "scripts/integration:🔵"
    "scripts/gateways:🔵"
    "scripts/ai:🟢"
    "scripts/agents:🟡"
    "scripts/analysis:🟢"
    "scripts/reports:🟢"
    "scripts/migration:🔵"
    "scripts/suites:🟡"
    "scripts/spiders:⚫"
    "scripts/testing:🟡"
    "scripts/unification:🔵"
    "collected_scripts:🟢"
    "collected_scripts_from_opt:⚫"
)

for category_info in "${categories[@]}"; do
    category="${category_info%:*}"
    status="${category_info#*:}"
    
    if [[ -d "/root/HyperFFactory/$category" ]]; then
        count=$(find "/root/HyperFFactory/$category" -type f -name "*.sh" -o -name "*.py" 2>/dev/null | wc -l)
        echo "$status $category - $count سكريبت"
    else
        echo "❌ $category - غير موجود"
    fi
    
    status_count["$status"]=$((status_count["$status"] + 1))
done

echo ""
echo "📊 إحصائيات الحالة:"
echo "=================================================="
echo "🟢 منتج: ${status_count[🟢]}"
echo "🟡 تجريبي: ${status_count[🟡]}" 
echo "🔵 مستورد: ${status_count[🔵]}"
echo "⚫ Legacy: ${status_count[⚫]}"
echo ""
echo "💡 التصنيف الكامل: /root/HyperFFactory/docs/scripts_catalog.md"

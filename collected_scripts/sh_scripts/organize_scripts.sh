#!/bin/bash

SCRIPT_CATEGORIES=(
    "core:sf_safe_startup.sh|sf_system_analyzer.sh|sf_system_health_report.sh"
    "health:sf_smart_monitor.sh|sf_services_status.sh|sf_quick_status.sh"
    "fix:sf_smart_repair_manager.sh|sf_quick_fix.sh|sf_real_fix.sh"
    "ai:sf_rebuild_knowledge_base.py|sf_scan_learning_all.sh|sf_run_net_learner_once.sh"
    "db:sf_remove_db_symlinks.sh|sf_setup_memory_identity.sql"
    "deploy:sf_start_actual_merge.sh|sf_start_enhanced_gateway.sh"
    "integration:sf_verify_knowledge_integration.sh|sf_update_learn_integration.py"
)

organize_scripts() {
    for category in "${SCRIPT_CATEGORIES[@]}"; do
        dir_name="${category%%:*}"
        patterns="${category##*:}"
        
        echo "📁 معالجة: $dir_name"
        mkdir -p "/root/HyperFFactory/scripts/$dir_name"
        
        IFS='|' read -ra pattern_array <<< "$patterns"
        for pattern in "${pattern_array[@]}"; do
            if [[ -f "/root/HyperFFactory/$pattern" ]]; then
                mv "/root/HyperFFactory/$pattern" "/root/HyperFFactory/scripts/$dir_name/"
                echo "   ✅ نقل: $pattern"
            fi
        done
    done
}

# تنفيذ التنظيم
organize_scripts
echo "🎯 اكتمل تنظيم السكريبتات!"

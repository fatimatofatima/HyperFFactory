#!/bin/bash
echo "🧠 SMART TURBO - مع إدارة القفل"

while true; do
    echo "🔄 دورة ذكية - $(date '+%H:%M:%S')"
    
    # فحص وإصلاح قفل قاعدة البيانات
    if [ -f "data/factory/factory.db-journal" ]; then
        echo "🔓 إصلاح قفل قاعدة البيانات..."
        ./hf_db_unlock.sh
    fi
    
    # تشغيل التقييم والأولويات
    timeout 10 ./hf_self_evaluation_system.sh
    timeout 5 ./hf_create_priority_files.sh
    
    # تشغيل المدير
    timeout 15 ./hf_run_manager_engine.sh
    
    # تشغيل المنفذ التلقائي
    timeout 10 ./hf_auto_executor.sh
    
    # انتظار قصير جداً لمنع القفل
    sleep 0.1
done

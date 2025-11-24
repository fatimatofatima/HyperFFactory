#!/bin/bash

echo "=================================================="
echo "   🔍 تحليل تناسق SmartFriend System"
echo "=================================================="
echo "الوقت: $(date)"
echo "=================================================="

# دالة للتحقق من وجود الملفات المهمة
check_critical_files() {
    echo ""
    echo "📁 الملفات الحرجة والتناسق بينها:"
    echo "================================="
    
    declare -A critical_files=(
        ["/opt/smartfriend-suite/var/db/memory.db"]="قاعدة الذاكرة الرئيسية"
        ["/opt/smartfriend-suite/var/db/smart_core_memory.db"]="ذاكرة العقل الأساسي"
        ["/opt/smartfriend-suite/var/db/unified_memory.db"]="الذاكرة الموحدة"
        ["/var/lib/smartfrind/smart_memory.db"]="الذاكرة التقليدية (Legacy)"
        ["/opt/smartfriend-suite/apps/smart_core/app.py"]="العقل الأساسي"
        ["/opt/smartfriend-suite/apps/unified/app.py"]="الواجهة الموحدة"
        ["/opt/smartfrind/continuous_learning.sh"]="التعلم المستمر"
        ["/opt/ffactory/docker-compose.yml"]="منصة FFactory"
    )
    
    for file in "${!critical_files[@]}"; do
        if [[ -f "$file" || -d "$file" ]]; then
            echo "✅ $file - ${critical_files[$file]}"
        else
            echo "❌ $file - ${critical_files[$file]} - مفقود!"
        fi
    done
}

# دالة لفحص تناسق قواعد البيانات
check_db_coherence() {
    echo ""
    echo "🗃️ تناسق قواعد البيانات:"
    echo "======================="
    
    dbs=(
        "/opt/smartfriend-suite/var/db/memory.db"
        "/opt/smartfriend-suite/var/db/smart_core_memory.db" 
        "/opt/smartfriend-suite/var/db/unified_memory.db"
        "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
        "/var/lib/smartfrind/smart_memory.db"
    )
    
    for db in "${dbs[@]}"; do
        if [[ -f "$db" ]]; then
            size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            echo ""
            echo "📊 $db - $(numfmt --to=iec $size)"
            
            # فحص الجداول الأساسية
            tables=$(sqlite3 "$db" ".tables" 2>/dev/null || echo "ERROR")
            if [[ "$tables" != "ERROR" ]]; then
                echo "   الجداول: $tables"
                
                # عد الصفوف في الجداول الرئيسية
                for table in sessions messages knowledge_items ai_memory knowledge_base; do
                    count=$(sqlite3 "$db" "SELECT COUNT(*) FROM $table;" 2>/dev/null || echo "0")
                    if [[ "$count" != "0" ]]; then
                        echo "   📈 $table: $count سجل"
                    fi
                done
            else
                echo "   ❌ قاعدة بيانات معطوبة أو غير قابلة للقراءة"
            fi
        fi
    done
}

# دالة لفحص تناسق الخدمات
check_services_coherence() {
    echo ""
    echo "🔄 تناسق الخدمات Systemd:"
    echo "========================"
    
    services=(
        "smartfrind-core.service"
        "smartfrind-local.service"
        "smartfrind-qa.service"
        "smartfrind-guardian.service"
        "smartfrind-trainer.service"
        "smartfrind-runner.service"
        "smartfrind-advanced.service"
        "smartfrind-ai-gateway.service"
        "smartfrind-harvest.service"
        "smartfrind-ingest.service"
        "smartfrind-reflector.service"
        "smartfrind-autolearn.service"
        "smartfrind-learning-agent.service"
        "smartfrind-envwatch.service"
        "smartfrind-monitor.service"
        "smartfrind-raw-clean.service"
        "sf-spider.service"
        "smartfriend-smartcore.service"
        "smartfriend-unified.service"
        "smartfrind-learning.service"
    )
    
    running_count=0
    enabled_count=0
    total_count=0
    
    for service in "${services[@]}"; do
        total_count=$((total_count + 1))
        
        if systemctl is-active "$service" >/dev/null 2>&1; then
            status="🟢 نشط"
            running_count=$((running_count + 1))
        else
            status="🔴 غير نشط"
        fi
        
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            enabled="✅ مُمكّن"
            enabled_count=$((enabled_count + 1))
        else
            enabled="❌ غير مُمكّن"
        fi
        
        echo "   $service - $status | $enabled"
    done
    
    echo ""
    echo "📊 إحصائيات الخدمات:"
    echo "   إجمالي الخدمات: $total_count"
    echo "   الخدمات النشطة: $running_count"
    echo "   الخدمات المُمكّنة: $enabled_count"
    echo "   نسبة النشاط: $((running_count * 100 / total_count))%"
}

# دالة لفحص تناسق البوابات
check_gateways_coherence() {
    echo ""
    echo "🌐 تناسق البوابات والموانئ:"
    echo "=========================="
    
    declare -A ports=(
        ["8000"]="FFactory Main Web"
        ["8170"]="FFactory Gateway"
        ["8211"]="Smart Core API"
        ["8214"]="Memory API"
        ["8220"]="Unified API"
        ["8221"]="Unified Gateway"
        ["8222"]="Learning Gateway"
        ["8223"]="Enhanced Gateway"
        ["5432"]="PostgreSQL"
        ["11434"]="Ollama"
    )
    
    active_ports=0
    total_ports=0
    
    for port in "${!ports[@]}"; do
        total_ports=$((total_ports + 1))
        if netstat -tulpn | grep ":$port " >/dev/null; then
            echo "   ✅ $port: ${ports[$port]} - نشط"
            active_ports=$((active_ports + 1))
        else
            echo "   ❌ $port: ${ports[$port]} - غير نشط"
        fi
    done
    
    echo ""
    echo "📊 إحصائيات البوابات:"
    echo "   إجمالي الموانئ: $total_ports"
    echo "   الموانئ النشطة: $active_ports"
    echo "   نسبة النشاط: $((active_ports * 100 / total_ports))%"
}

# دالة لفحص التعارضات
check_conflicts() {
    echo ""
    echo "⚡ فحص التعارضات المحتملة:"
    echo "=========================="
    
    conflicts_found=0
    
    # فحص 1: تكرار قواعد البيانات
    echo ""
    echo "1. تكرار قواعد البيانات:"
    db_patterns=("memory.db" "unified.db" "smart_core")
    for pattern in "${db_patterns[@]}"; do
        duplicates=$(find /opt /var -name "*${pattern}*" -type f 2>/dev/null | wc -l)
        if [[ $duplicates -gt 1 ]]; then
            echo "   ⚠️  يوجد $duplicates نسخة من *${pattern}*"
            find /opt /var -name "*${pattern}*" -type f 2>/dev/null
            conflicts_found=$((conflicts_found + 1))
        fi
    done
    
    # فحص 2: تكرار الخدمات
    echo ""
    echo "2. تكرار الخدمات:"
    service_patterns=("smartfrind" "smartfriend" "sf-")
    for pattern in "${service_patterns[@]}"; do
        duplicates=$(systemctl list-unit-files | grep "$pattern" | wc -l)
        if [[ $duplicates -gt 5 ]]; then
            echo "   ⚠️  يوجد $duplicates خدمة تطابق '$pattern'"
            conflicts_found=$((conflicts_found + 1))
        fi
    done
    
    # فحص 3: تعارض الموانئ
    echo ""
    echo "3. تعارض الموانئ:"
    port_conflicts=$(netstat -tulpn | awk '{print $4}' | grep -oE ':[0-9]+' | cut -d: -f2 | sort | uniq -d)
    if [[ -n "$port_conflicts" ]]; then
        echo "   ⚠️  تعارض في الموانئ: $port_conflicts"
        conflicts_found=$((conflicts_found + 1))
    fi
    
    # فحص 4: مسارات مكررة
    echo ""
    echo "4. مسارات مكررة:"
    important_paths=("/opt/smartfriend" "/opt/ffactory" "/opt/smartfrind")
    for path in "${important_paths[@]}"; do
        if [[ -d "$path" ]]; then
            similar_paths=$(find /opt -maxdepth 1 -type d -name "*$(basename "$path")*" | wc -l)
            if [[ $similar_paths -gt 1 ]]; then
                echo "   ⚠️  مسارات مشابهة لـ $path:"
                find /opt -maxdepth 1 -type d -name "*$(basename "$path")*"
                conflicts_found=$((conflicts_found + 1))
            fi
        fi
    done
    
    return $conflicts_found
}

# دالة لتقييم التناسق العام
evaluate_coherence() {
    echo ""
    echo "🎯 تقييم التناسق العام:"
    echo "======================"
    
    total_score=0
    max_score=100
    
    # معايير التقييم
    criteria=(
        "الملفات الحرجة:20"
        "قواعد البيانات:25" 
        "الخدمات:25"
        "البوابات:20"
        "عدم التعارض:10"
    )
    
    # حساب النقاط
    critical_files_count=$(check_critical_files | grep "✅" | wc -l)
    files_score=$((critical_files_count * 20 / 8))
    total_score=$((total_score + files_score))
    
    db_count=$(check_db_coherence | grep "📊" | wc -l)
    db_score=$((db_count * 25 / 5))
    total_score=$((total_score + db_score))
    
    services_running=$(check_services_coherence | grep "🟢 نشط" | wc -l)
    services_score=$((services_running * 25 / 20))
    total_score=$((total_score + services_score))
    
    ports_active=$(check_gateways_coherence | grep "✅" | wc -l)
    ports_score=$((ports_active * 20 / 9))
    total_score=$((total_score + ports_score))
    
    check_conflicts
    conflicts=$?
    conflict_score=$((10 - conflicts))
    total_score=$((total_score + conflict_score))
    
    # التقييم النهائي
    echo ""
    echo "📈 نتائج التقييم:"
    echo "   الملفات الحرجة: $files_score/20"
    echo "   قواعد البيانات: $db_score/25"
    echo "   الخدمات: $services_score/25"
    echo "   البوابات: $ports_score/20"
    echo "   عدم التعارض: $conflict_score/10"
    echo "   المجموع: $total_score/100"
    
    echo ""
    echo "🏆 الحكم النهائي:"
    if [[ $total_score -ge 80 ]]; then
        echo "   🎉 تناسق ممتاز - النظام متجانس ومتكامل"
    elif [[ $total_score -ge 60 ]]; then
        echo "   👍 تناسق جيد - بعض التحسينات المطلوبة"
    elif [[ $total_score -ge 40 ]]; then
        echo "   ⚠️  تناسق متوسط - توجد تعارضات تحتاج معالجة"
    else
        echo "   ❌ تناسق ضعيف - توجد تعارضات كبيرة"
    fi
    
    # التوصيات
    echo ""
    echo "💡 التوصيات:"
    if [[ $conflicts -gt 0 ]]; then
        echo "   • معالجة التعارضات المكتشفة ($conflicts تعارض)"
    fi
    if [[ $services_running -lt 10 ]]; then
        echo "   • تشغيل المزيد من الخدمات الأساسية"
    fi
    if [[ $ports_active -lt 5 ]]; then
        echo "   • تفعيل البوابات الأساسية"
    fi
}

# التنفيذ الرئيسي
main() {
    check_critical_files
    check_db_coherence
    check_services_coherence
    check_gateways_coherence
    check_conflicts
    evaluate_coherence
    
    echo ""
    echo "=================================================="
    echo "تم تحليل التناسق بنجاح! 🎯"
    echo "=================================================="
}

# تشغيل التحليل
main

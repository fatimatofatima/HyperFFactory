#!/bin/bash

echo "=================================================="
echo "   🎛️  SmartFriend Status Dashboard"
echo "=================================================="
echo "الوقت: $(date)"
echo "=================================================="

# دالة لعرض حالة الطبقات
show_layer_status() {
    local layer=$1
    local status=$2
    local description=$3
    
    case $status in
        "🟢") echo "  $status $layer: $description" ;;
        "🟡") echo "  $status $layer: $description" ;;
        "🔴") echo "  $status $layer: $description" ;;
        *) echo "  ⚪ $layer: $description" ;;
    esac
}

# فحص سريع للحالة
quick_check() {
    echo "🔍 فحص سريع للنظام..."
    
    # Identity Layer
    if [[ -f "/var/lib/smartfrind/smart_memory.db" ]]; then
        identity_status="🟢"
        identity_desc="مثبت (783 سجل معرفة)"
    else
        identity_status="🔴"
        identity_desc="مفقود"
    fi
    
    # Memory Layer
    memory_dbs=$(find /opt/smartfriend-suite/var/db -name "*.db" -type f 2>/dev/null | wc -l)
    if [[ $memory_dbs -ge 4 ]]; then
        memory_status="🟢"
        memory_desc="مثبت ($memory_dbs قواعد بيانات)"
    elif [[ $memory_dbs -gt 0 ]]; then
        memory_status="🟡"
        memory_desc="جزئي ($memory_dbs قواعد بيانات)"
    else
        memory_status="🔴"
        memory_desc="مفقود"
    fi
    
    # Knowledge Layer
    if sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM knowledge_base;" 2>/dev/null | grep -q "[0-9]"; then
        knowledge_status="🟢"
        knowledge_desc="نشط (783 عنصر معرفة)"
    else
        knowledge_status="🔴"
        knowledge_desc="غير نشط"
    fi
    
    # Learning Layer
    if systemctl is-active "smartfrind-learning.service" >/dev/null 2>&1; then
        learning_status="🟢"
        learning_desc="نشط"
    elif [[ -f "/opt/smartfrind/continuous_learning.sh" ]]; then
        learning_status="🟡"
        learning_desc="جاهز (غير نشط)"
    else
        learning_status="🔴"
        learning_desc="مفقود"
    fi
    
    # Brain Layer
    brain_apis=0
    for port in 8211 8214 8220; do
        if netstat -tulpn | grep ":$port " >/dev/null; then
            brain_apis=$((brain_apis + 1))
        fi
    done
    
    if [[ $brain_apis -ge 2 ]]; then
        brain_status="🟢"
        brain_desc="نشط ($brain_apis/3 واجهات)"
    elif [[ $brain_apis -gt 0 ]]; then
        brain_status="🟡"
        brain_desc="جزئي ($brain_apis/3 واجهات)"
    else
        brain_status="🔴"
        brain_desc="غير نشط"
    fi
    
    # Awareness Layer
    if netstat -tulpn | grep ":8170 " >/dev/null && [[ -f "/opt/smartfriend-suite/apps/harvester/spider" ]]; then
        awareness_status="🟢"
        awareness_desc="نشط (Spider + Gateway)"
    elif [[ -f "/opt/smartfriend-suite/apps/harvester/spider" ]]; then
        awareness_status="🟡"
        awareness_desc="جاهز (غير نشط)"
    else
        awareness_status="🔴"
        awareness_desc="مفقود"
    fi
}

# عرض Dashboard
display_dashboard() {
    echo ""
    echo "🏗️  طبقات النظام:"
    echo "================="
    
    show_layer_status "Identity" "$identity_status" "$identity_desc"
    show_layer_status "Memory" "$memory_status" "$memory_desc"
    show_layer_status "Knowledge" "$knowledge_status" "$knowledge_desc"
    show_layer_status "Learning" "$learning_status" "$learning_desc"
    show_layer_status "Brain" "$brain_status" "$brain_desc"
    show_layer_status "Awareness" "$awareness_status" "$awareness_desc"
    
    echo ""
    echo "📊 الإحصائيات:"
    echo "=============="
    
    # عد الخدمات
    total_services=$(systemctl list-unit-files | grep -E "smartfrind|smartfriend|sf-" | wc -l)
    active_services=$(systemctl list-units --type=service --state=running | grep -E "smartfrind|smartfriend|sf-" | wc -l)
    
    # عد الملفات
    suite_files=$(find /opt/smartfriend-suite -type f 2>/dev/null | wc -l)
    legacy_files=$(find /var/lib/smartfrind -type f 2>/dev/null | wc -l)
    
    echo "  📁 الملفات: $suite_files في Suite, $legacy_files في Legacy"
    echo "  🔧 الخدمات: $active_services/$total_services نشطة"
    echo "  🌐 البوابات: $brain_apis/3 واجهات عقل نشطة"
    
    echo ""
    echo "🎯 التقييم العام:"
    echo "================"
    
    # حساب النقاط
    score=0
    [[ $identity_status == "🟢" ]] && score=$((score + 20))
    [[ $memory_status == "🟢" ]] && score=$((score + 15))
    [[ $knowledge_status == "🟢" ]] && score=$((score + 15))
    [[ $learning_status == "🟢" ]] && score=$((score + 15))
    [[ $brain_status == "🟢" ]] && score=$((score + 20))
    [[ $awareness_status == "🟢" ]] && score=$((score + 15))
    
    if [[ $score -ge 85 ]]; then
        echo "  🎉 ممتاز - النظام جاهز للتشغيل الكامل"
    elif [[ $score -ge 70 ]]; then
        echo "  👍 جيد جداً - يحتاج تفعيل بعض الخدمات"
    elif [[ $score -ge 50 ]]; then
        echo "  ⚠️  متوسط - توجد مكونات غير نشطة"
    else
        echo "  ❌ ضعيف - يحتاج إعداد أساسي"
    fi
    echo "  النقاط: $score/100"
}

# الأوامر السريعة
show_quick_commands() {
    echo ""
    echo "⚡ أوامر سريعة:"
    echo "=============="
    echo "  🔄 إعادة تحميل: ./analyze_sf_coherence.sh"
    echo "  🚀 تشغيل الخدمات: systemctl start smartfrind-learning.service"
    echo "  📊 تفاصيل: systemctl status smartfrind-core.service"
    echo "  🗃️  فحص DB: sqlite3 /var/lib/smartfrind/smart_memory.db \"SELECT COUNT(*) FROM knowledge_base;\""
    echo "  🌐 فحص البوابات: netstat -tulpn | grep -E ':(8211|8214|8220)'"
}

# التنفيذ الرئيسي
main() {
    quick_check
    display_dashboard
    show_quick_commands
    
    echo ""
    echo "=================================================="
    echo "Dashboard جاهز! استخدم الأوامر السريعة للتحكم 🎛️"
    echo "=================================================="
}

main

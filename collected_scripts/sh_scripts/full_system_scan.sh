#!/bin/bash

echo "================================================"
echo "   🔍 مسح شامل للنظام والخدمات"
echo "================================================"
echo "الوقت: $(date)"
echo "المستخدم: $(whoami)"
echo "النظام: $(hostname)"
echo "================================================"

# دالة للتحقق من حالة الخدمة
check_service() {
    local service=$1
    local description=$2
    
    if systemctl is-active "$service" >/dev/null 2>&1; then
        status="🟢 نشط"
    else
        status="🔴 غير نشط"
    fi
    
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        enabled="✅ مُمكّن"
    else
        enabled="❌ غير مُمكّن"
    fi
    
    echo "  $service - $description"
    echo "    الحالة: $status | التمكين: $enabled"
}

# قسم الخدمات النشطة
echo ""
echo "🚦 الخدمات النشطة حالياً:"
echo "=========================="
systemctl list-units --type=service --state=running | head -20

# قسم جميع خدمات النظام
echo ""
echo "📋 جميع خدمات النظام:"
echo "====================="

# خدمات systemd الرئيسية
echo "🔧 خدمات Systemd الأساسية:"
check_service "ssh" "خدمة SSH"
check_service "cron" "المجدولات"
check_service "nginx" "خادم الويب"
check_service "apache2" "خادم Apache"
check_service "mysql" "قاعدة البيانات MySQL"
check_service "postgresql" "قاعدة البيانات PostgreSQL"
check_service "docker" "Docker"
check_service "redis" "Redis"

# خدمات SmartFriend
echo ""
echo "🤖 خدمات SmartFriend:"
services=(
    "smartfrind-core.service:العقل الأساسي"
    "smartfrind-local.service:العقل المحلي" 
    "smartfrind-qa.service:الأسئلة والأجوبة"
    "smartfrind-guardian.service:الحماية"
    "smartfrind-trainer.service:التدريب"
    "smartfrind-runner.service:التنفيذ"
    "smartfrind-advanced.service:العقل المتقدم"
    "smartfrind-ai-gateway.service:بوابة الذكاء الاصطناعي"
    "smartfrind-harvest.service:الحصاد"
    "smartfrind-ingest.service:الاستيعاب"
    "smartfrind-reflector.service:العاكس"
    "smartfrind-autolearn.service:التعلم التلقائي"
    "smartfrind-learning-agent.service:وكيل التعلم"
    "smartfrind-envwatch.service:مراقبة البيئة"
    "smartfrind-monitor.service:المراقب"
    "smartfrind-raw-clean.service:التنظيف"
    "sf-spider.service:العناكب"
)

for service_info in "${services[@]}"; do
    IFS=':' read -r service description <<< "$service_info"
    check_service "$service" "$description"
done

# قسم العمليات النشطة
echo ""
echo "⚡ العمليات النشطة حالياً:"
echo "========================="
ps aux --sort=-%cpu | head -15

# قسم استخدام الذاكرة
echo ""
echo "💾 استخدام الذاكرة:"
echo "==================="
free -h

# قسم استخدام القرص
echo ""
echo "💿 استخدام القرص:"
echo "================="
df -h / /opt /home

# قسم الملفات الكبيرة
echo ""
echo "📦 أكبر 10 ملفات في النظام:"
echo "==========================="
find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null | head -10 | awk '{print $5, $9}'

# قسم الملفات المفتوحة
echo ""
echo "🔓 الملفات المفتوحة:"
echo "===================="
lsof 2>/dev/null | head -20

# قسم الشبكة
echo ""
echo "🌐 اتصالات الشبكة النشطة:"
echo "========================="
netstat -tulpn 2>/dev/null | head -20

# قسم التحقق من الموانئ
echo ""
echo "🔌 الموانئ المستخدمة من SmartFriend:"
echo "===================================="
declare -A sf_ports=(
    ["8170"]="FFactory Gateway"
    ["8171"]="Smart Core API" 
    ["8172"]="Learning API"
    ["8173"]="Identity API"
    ["8174"]="Spider Service"
    ["8175"]="Monitor Service"
)

for port in "${!sf_ports[@]}"; do
    if netstat -tulpn | grep ":$port " >/dev/null; then
        echo "  ✅ الميناء $port: ${sf_ports[$port]} - نشط"
    else
        echo "  ❌ الميناء $port: ${sf_ports[$port]} - غير نشط"
    fi
done

# قسم الخلاصة
echo ""
echo "📊 خلاصة النظام:"
echo "================"

total_services=$(systemctl list-units --type=service --all | wc -l)
active_services=$(systemctl list-units --type=service --state=running | wc -l)
failed_services=$(systemctl list-units --type=service --state=failed | wc -l)

echo "📊 إجمالي الخدمات: $((total_services - 1))"
echo "🟢 الخدمات النشطة: $((active_services - 1))"
echo "🔴 الخدمات الفاشلة: $((failed_services - 1))"

# حساب استخدام النظام
load=$(uptime | awk -F'load average:' '{print $2}')
memory_usage=$(free | awk 'NR==2{printf "%.2f%%", $3*100/$2}')
disk_usage=$(df / | awk 'NR==2{printf "%s", $5}')

echo "📈 حمل النظام: $load"
echo "💾 استخدام الذاكرة: $memory_usage"
echo "💿 استخدام القرص الرئيسي: $disk_usage"

echo ""
echo "================================================"
echo "تم المسح الشامل بنجاح! 🎯"
echo "================================================"

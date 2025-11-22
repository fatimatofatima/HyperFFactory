#!/bin/bash
echo "🏥 FFactory Health Check - فحص الصحة الشامل"
echo "=========================================="
echo "⏰ $(date)"
echo ""

# 1. فحص البورت 8170
echo "1. 🌐 فحص البورت 8170:"
if curl -s http://127.0.0.1:8170/health > /dev/null; then
    echo "   ✅ البورت 8170: شغال ومستجيب"
else
    echo "   ❌ البورت 8170: معطل - جاري إعادة التشغيل..."
    systemctl restart sf-factory
fi

# 2. فحص الخدمات
echo "2. 🔧 فحص الخدمات:"
services=("sf-factory" "ff-doctor" "ff-selfaware")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "   ✅ $service: نشط"
    else
        echo "   ❌ $service: معطل"
    fi
done

# 3. فحص Docker
echo "3. 🐳 فحص Docker:"
if docker ps > /dev/null 2>&1; then
    echo "   ✅ Docker: شغال"
    echo "   📊 الحاويات النشطة: $(docker ps -q | wc -l)"
else
    echo "   ❌ Docker: معطل"
fi

# 4. فحص الموارد
echo "4. 💻 فحص الموارد:"
echo "   💾 الذاكرة: $(free -h | awk 'NR==2{print $3"/"$2 " ("$4" free)"}')"
echo "   💽 التخزين: $(df -h /opt | awk 'NR==2{print $3"/"$2 " ("$5" used)"}')"
echo "   🖥️  التحميل: $(uptime | awk -F'load average:' '{print $2}')"

echo ""
echo "✅ فحص الصحة اكتمل"

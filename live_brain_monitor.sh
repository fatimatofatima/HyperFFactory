#!/bin/bash

echo "🧠 === مراقب العقل الحي المتقدم ==="
echo "⏰ $(date)"
echo "=================================="

# 1. حالة الذاكرة
echo "📊 الذاكرة:"
echo "   • قواعد البيانات: $(find /opt/hyper-factory/var/db/ -name "*.db" | wc -l)"
echo "   • المساحة المتاحة: $(df -h /opt | awk 'NR==2 {print $4}')"

# 2. حالة الخدمات
echo "🔧 الخدمات:"
services=("factory-gw.service" "postgresql@16-main.service" "docker.service")
for service in "${services[@]}"; do
    if systemctl is-active --quiet $service; then
        echo "   ✅ $service"
    else
        echo "   ❌ $service"
    fi
done

# 3. حالة التعلم
echo "📈 التعلم:"
if ps aux | grep -q "[p]ython3.*learning"; then
    echo "   ✅ نظام التعلم نشط"
else
    echo "   🔄 نظام التعلم متوقف - جاري التشغيل..."
    python3 self_learning_brain.py &
fi

# 4. التوصيات الذكية
echo "💡 التوصيات:"
if ! systemctl is-active --quiet sf-memory.service; then
    echo "   🔧 إصلاح خدمة الذاكرة: sudo systemctl restart sf-memory.service"
fi

if [ $(find /opt/hyper-factory/var/db/ -name "*.db" | wc -l) -lt 5 ]; then
    echo "   🗄️ تفعيل قواعد البيانات المتبقية"
fi

echo "🚀 العقل الشامل: نشط وجاهز للإدارة"

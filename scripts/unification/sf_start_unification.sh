#!/bin/bash
echo "🚀 بدء تنفيذ خطة التوحيد - الخطوة الأولى"
echo

# 1. إصلاح الخدمات الأساسية أولاً
echo "1. إصلاح الخدمات الأساسية للسيوت:"
services_to_fix=("sf-memory.service" "sf-web.service" "sf-health.service" "sf-spider.service")

for service in "${services_to_fix[@]}"; do
    echo "   🔧 معالجة $service"
    sudo systemctl status "$service" --no-pager | grep -q "Active: active" && {
        echo "      ✅ الخدمة نشطة بالفعل"
    } || {
        echo "      ⚠️  محاولة إصلاح الخدمة"
        sudo systemctl restart "$service"
        sleep 2
        sudo systemctl status "$service" --no-pager | grep -q "Active: active" && {
            echo "      ✅ تم إصلاح الخدمة"
        } || {
            echo "      ❌ تحتاج تدخل يدوي"
        }
    }
done

# 2. تحديد الخدمات القوية من smartfrind-* لنقل منطقها
echo
echo "2. تحديد الخدمات القوية لنقل المنطق:"
strong_services=$(systemctl list-units "smartfrind-*" --no-legend --state=active | awk '{print $1}' | head -5)

for service in $strong_services; do
    echo "   💡 $service - جاهز لنقل المنطق"
    # هنا سنضيف منطق نقل الكود لاحقاً
done

# 3. إيقاف البوتات المكررة
echo
echo "3. معالجة تضاربات البوتات:"
sudo systemctl stop sf-bot-model.service 2>/dev/null && echo "   ✅ تم إيقاف sf-bot-model.service"
sudo systemctl stop smartfrind-bot.service 2>/dev/null && echo "   ✅ تم إيقاف smartfrind-bot.service"

# 4. بدء البوت الرئيسي فقط
echo
echo "4. تفعيل البوت الرئيسي:"
sudo systemctl start sf-bot.service
sleep 3
sudo systemctl is-active sf-bot.service && echo "   ✅ البوت الرئيسي يعمل" || echo "   ❌ البوت الرئيسي يحتاج إصلاح"

echo
echo "🎯 الخطوة القادمة: نقل المنطق القوي من smartfrind-* إلى sf-*"

#!/bin/bash
echo "📊 تقرير متابعة توحيد SmartFriend Suite - $(date)"
echo "================================================"

echo
echo "الخدمات النشطة من sf-*:"
systemctl list-units "sf-*" --no-legend --state=active | wc -l | xargs echo "   عدد الخدمات النشطة:"

echo
echo "الخدمات المتبقية من smartfrind-*:"
systemctl list-units "smartfrind-*" --no-legend --state=active | wc -l | xargs echo "   عدد الخدمات النشطة:"

echo
echo "البورتات النشطة:"
ss -tulpn | grep -E ":(8210|8211|8214|8220|8383|8390)" | awk '{print "   📡 " $5}'

echo
echo "أهم الأخطاء في السجلات:"
journalctl -u "sf-*" --since "1 hour ago" | grep -i error | tail -3 | while read line; do
    echo "   ⚠️  $line"
done

echo
echo "✅ الإنجازات اليومية:"
echo "   - تم إنشاء خطة التوحيد الشاملة"
echo "   - تم تحليل قوة جميع الخدمات"
echo "   - تم بدء إصلاح الخدمات الأساسية"
echo
echo "🎯 المستهدف للغد:"
echo "   - نقل أول منطق قوي من smartfrind-* إلى sf-*"
echo "   - إصلاح 3 خدمات أساسية على الأقل"
echo "   - تقليل خدمات smartfrind-* النشطة بنسبة 50%"

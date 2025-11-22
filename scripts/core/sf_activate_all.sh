#!/bin/bash
set -euo pipefail

echo "=== تفعيل وتشغيل جميع خدمات SmartFriend Suite ==="
echo "⚠️  تحذير: لن يتم لمس أي خدمة تابعة لـ ffactory"
echo ""

# الحصول على جميع خدمات smartfriend-suite فقط
SERVICES=$(systemctl list-unit-files --type=service 2>/dev/null | \
           awk '/^(sf-|smartfriend|smartfrind)/ && !/ffactory/ {print $1}')

echo "📋 عدد الخدمات المكتشفة: $(echo "$SERVICES" | wc -l)"
echo ""

# تفعيل وتشغيل جميع الخدمات
for service in $SERVICES; do
    echo "🔧 معالجة: $service"
    
    # تفعيل الخدمة
    if systemctl enable "$service" 2>/dev/null; then
        echo "  ✅ تم تفعيل الخدمة"
    else
        echo "  ⚠️  لم يتم تفعيل الخدمة (ممكن تكون معطلة)"
    fi
    
    # تشغيل الخدمة
    if systemctl start "$service" 2>/dev/null; then
        echo "  ✅ تم تشغيل الخدمة"
    else
        echo "  ❌ فشل تشغيل الخدمة"
        # عرض آخر سجلات الخطأ
        journalctl -u "$service" -n 3 --no-pager 2>/dev/null | \
        while read line; do
            echo "    📝 $line"
        done
    fi
    echo ""
done

echo "=== فحص الحالة النهائية ==="
echo ""

echo "🟢 الخدمات النشطة:"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager --no-legend | grep -v ffactory

echo ""
echo "🔴 الخدمات الفاشلة:"
systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-pager --no-legend | grep -v ffactory

echo ""
echo "=== تم الانتهاء ==="

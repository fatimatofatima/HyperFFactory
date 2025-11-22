#!/bin/bash
echo "=== فحص حالة الخدمات بعد تحديث التوكنات ==="
echo

echo "1. البوتات النشطة:"
systemctl list-units "sf-*bot*" "sf-*telegram*" --no-legend --state=active | awk '{print "   ✅ " $1}'

echo
echo "2. الخدمات الفاشلة:"
systemctl list-units "sf-*" --no-legend --state=failed | awk '{print "   ❌ " $1}'

echo
echo "3. أخطاء البوتات:"
for bot in sf-bot.service sf-bot-model.service sf-telegram.service sf-smartfrind.service; do
    if systemctl is-active "$bot" >/dev/null; then
        echo "   🔍 فحص $bot:"
        journalctl -u "$bot" -n 5 --no-pager 2>/dev/null | grep -E "(error|Error|ERROR|Conflict|InvalidToken)" | head -3 || echo "      لا توجد أخطاء"
    fi
done

echo
echo "4. البورتات النشطة:"
ss -tulpn | grep -E ":(8210|8211|8214|8220|8383|8390)" | awk '{print "   📡 " $5}'

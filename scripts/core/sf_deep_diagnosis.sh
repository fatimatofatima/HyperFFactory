#!/bin/bash
echo "🔍 التشخيص التفصيلي للمشاكل الفنية"

echo "1. فحص مشاكل Python Path:"
echo "   - مسار venv السيوت: $(ls -la /opt/smartfriend-suite/smartfriend/venv/bin/python 2>/dev/null || echo '❌ غير موجود')"
echo "   - مجلد apps: $(ls -la /opt/smartfriend-suite/apps/ | head -10)"
echo "   - ملفات unified: $(ls -la /opt/smartfriend-suite/apps/unified/ 2>/dev/null || echo '❌ غير موجود')"

echo
echo "2. فحص مشاكل التوكنات:"
for bot in sf-audit-bot.service sf-telegram-audit.service; do
    echo "   - $bot:"
    sudo journalctl -u "$bot" -n 3 --no-pager 2>/dev/null | grep -i "token\|error" || echo "      لا توجد أخطاء حديثة"
done

echo
echo "3. فحص بقايا Legacy:"
echo "   - Processes نشطة:"
ps aux | grep smartfrind | grep -v grep || echo "      لا توجد processes نشطة"
echo "   - البورت 8210:"
ss -tulpn | grep ":8210" | awk '{print "      Process: " $7}'

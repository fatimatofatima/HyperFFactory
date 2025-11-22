#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار البوابة المتكاملة بعد التحديث..."

# إعادة تشغيل البوابة إذا كانت شغالة
echo "🔄 إعادة تشغيل البوابة..."
pkill -f "unified_gateway.py" || true
sleep 2

cd /opt/smartfriend-suite
python3 bots/app/smartfrind/unified_gateway.py &

sleep 3

echo ""
echo "1. 🔍 اختبار البحث المتكامل:"
curl -s "http://localhost:8000/api/search?query=python&limit=2" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(f'✅ النتائج: {len(data.get(\\\"items\\\", []))} عنصر')
    print(f'📊 المصدر: {data.get(\\\"source\\\", \\\"غير معروف\\\")}')
    if 'items' in data and len(data['items']) > 0:
        first = data['items'][0]
        print(f'📝 العنصر الأول: {first.get(\\\"category\\\", \\\"N/A\\\")} - {first.get(\\\"question\\\", \\\"\\\")[:50]}...')
except Exception as e:
    print(f'❌ خطأ في الاستجابة: {e}')
"

echo ""
echo "2. ❤️ اختبار الصحة:"
curl -s "http://localhost:8000/health" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "3. 📋 فحص السجلات الحديثة:"
journalctl -u smartfriend --since "2 minutes ago" 2>/dev/null | tail -5 || echo "⚠️ لا توجد سجلات حديثة"

echo ""
echo "🎯 اختبار التكامل اكتمل!"

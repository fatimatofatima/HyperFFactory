#!/usr/bin/env bash
set -Eeuo pipefail

echo "🎯 الاختبار النهائي للتكامل الكامل..."

echo ""
echo "1. 🌐 حالة جميع البوابات:"
PORTS=(8221 8222 8223)
for port in "${PORTS[@]}"; do
    echo -n "   • المنفذ $port: "
    if curl -s http://localhost:$port/health > /dev/null; then
        echo "✅ شغال"
    else
        echo "❌ غير شغال"
    fi
done

echo ""
echo "2. 🔍 اختبار البحث من البوابة المحسنة:"
curl -s "http://localhost:8223/api/v2/search?query=python&limit=3" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    count = data.get('count', 0)
    source = data.get('source', 'unknown')
    status = data.get('status', 'unknown')
    print(f'   • الحالة: {status}')
    print(f'   • النتائج: {count} عنصر') 
    print(f'   • المصدر: {source}')
    if count > 0:
        first = data['items'][0]
        print(f'   • المثال: {first.get(\"category\", \"N/A\")}')
except Exception as e:
    print(f'   • خطأ: {e}')
"

echo ""
echo "3. 🎓 اختبار التعلم من البوابة المحسنة:"
curl -s "http://localhost:8223/api/v2/learn/random" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    status = data.get('status', 'unknown')
    source = data.get('source', 'unknown')
    print(f'   • الحالة: {status}')
    print(f'   • المصدر: {source}')
    if data.get('data') and data['data'].get('item'):
        item = data['data']['item']
        print(f'   • التصنيف: {item.get(\"category\", \"N/A\")}')
except Exception as e:
    print(f'   • خطأ: {e}')
"

echo ""
echo "4. 📊 قاعدة البيانات:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT '• ai_memory: ' || COUNT(*) FROM ai_memory
UNION ALL  
SELECT '• ai_memory_fts: ' || COUNT(*) FROM ai_memory_fts
UNION ALL
SELECT '• knowledge_base: ' || COUNT(*) FROM knowledge_base;"

echo ""
echo "5. 📋 السجلات الحديثة:"
echo "   🔍 بوابة البحث (8221):"
tail -3 /var/log/sf_simple_knowledge_gateway.log 2>/dev/null | while read line; do echo "      $line"; done || echo "      ℹ️ لا توجد سجلات"
echo "   🚀 البوابة المحسنة (8223):"
tail -3 /var/log/sf_enhanced_gateway_fixed.log 2>/dev/null | while read line; do echo "      $line"; done || echo "      ℹ️ لا توجد سجلات"

echo ""
echo "✅ اكتمل الاختبار النهائي"

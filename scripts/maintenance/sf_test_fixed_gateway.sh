#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار شامل للبوابة المصححة..."

echo ""
echo "1. ❤️ اختبار الصحة:"
curl -s "http://localhost:8223/health" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'   الخدمة: {data.get(\"service\", \"N/A\")}')
print(f'   الحالة: {data.get(\"status\", \"N/A\")}')
print(f'   نظام المعرفة: {data.get(\"knowledge_system\", \"N/A\")}')
"

echo ""
echo "2. 🔍 اختبار البحث:"
curl -s "http://localhost:8223/api/v2/search?query=python&limit=3" | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = data.get('count', 0)
source = data.get('source', 'unknown')
print(f'   النتائج: {count} عنصر')
print(f'   المصدر: {source}')
if count > 0:
    first = data['items'][0]
    category = first.get('category', 'N/A')
    question = first.get('question', '')[:50]
    print(f'   المثال: {category} - {question}...')
"

echo ""
echo "3. 🎓 اختبار التعلم العشوائي:"
curl -s "http://localhost:8223/api/v2/learn/random" | python3 -c "
import json, sys
data = json.load(sys.stdin)
status = data.get('status', 'unknown')
source = data.get('source', 'unknown')
print(f'   الحالة: {status}')
print(f'   المصدر: {source}')
if data.get('data') and data['data'].get('item'):
    item = data['data']['item']
    category = item.get('category', 'N/A')
    print(f'   التصنيف: {category}')
"

echo ""
echo "4. 📋 فحص السجلات:"
echo '   📄 آخر 5 سجلات:'
tail -5 /var/log/sf_enhanced_gateway_fixed.log 2>/dev/null | while read line; do
    echo "      $line"
done

echo ""
echo "✅ اكتمل اختبار البوابة المصححة"

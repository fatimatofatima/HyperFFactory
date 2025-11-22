#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار البوابة المحسنة مع نظام المعرفة..."

echo ""
echo "1. 🔍 اختبار البحث المحسن:"
curl -s "http://localhost:8223/api/v2/search?query=python&limit=2" | python3 -m json.tool

echo ""
echo "2. 🎓 اختبار التعلم المحسن:"
curl -s "http://localhost:8223/api/v2/learn/random" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'   ✅ النتيجة: {data.get(\\\"status\\\", \\\"N/A\\\")}')
if 'item' in data:
    item = data['item']
    print(f'   📚 الصنف: {item.get(\\\"category\\\", \\\"N/A\\\")}')
"

echo ""
echo "3. ❤️ اختبار الصحة:"
curl -s "http://localhost:8223/health" | python3 -m json.tool

echo ""
echo "🎯 مقارنة مع النظام القديم:"
echo "   القديم (8221): http://localhost:8221/api/knowledge/search?query=python&limit=1"
echo "   الجديد (8223): http://localhost:8223/api/v2/search?query=python&limit=1"

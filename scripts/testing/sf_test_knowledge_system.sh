#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار نظام المعرفة الموحد..."

# اختبار البحث في knowledge_base
echo "1. 🔍 اختبار البحث في قاعدة المعرفة:"
curl -s "http://localhost:8221/api/knowledge/search?query=python&limit=3" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "2. 🏷️ اختبار التصنيفات:"
curl -s "http://localhost:8221/api/knowledge/categories" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "3. 📊 اختبار الإحصائيات:"
curl -s "http://localhost:8221/api/knowledge/stats" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "4. 🎓 اختبار المحتوى التعليمي:"
curl -s "http://localhost:8222/api/learn/random" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "5. 🔄 اختبار interactive learning:"
curl -s "http://localhost:8222/api/learn/interactive" | python3 -m json.tool || echo "❌ الخدمة غير متاحة"

echo ""
echo "✅ اختبار النظام المحدث اكتمل!"

#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🎯 الفحص النهائي الشامل"
echo "==========================================="

DB_MAIN="/var/lib/smartfrind/smart_memory.db"

echo "📊 حالة قواعد البيانات:"
sqlite3 "$DB_MAIN" "
SELECT '🤖 ai_memory: ' || COUNT(*) || ' سجل' FROM ai_memory;
SELECT '📚 knowledge_base: ' || COUNT(*) || ' سجل' FROM knowledge_base;
SELECT '🔍 FTS Index: ' || COUNT(*) || ' سجل' FROM ai_memory_fts;
"

echo "🏷️ توزيع التصنيفات في knowledge_base:"
sqlite3 "$DB_MAIN" "
SELECT category, COUNT(*) as count 
FROM knowledge_base 
GROUP BY category 
ORDER BY count DESC
LIMIT 15;
"

echo "🚀 الخدمات النشطة:"
ps aux | grep -E "(uvicorn|python.*smart)" | grep -v grep | while read line; do
    echo "   🔄 $line" | cut -c1-80
done

echo "✅ الفحص اكتمل!"

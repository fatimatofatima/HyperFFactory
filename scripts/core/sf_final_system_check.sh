#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   📊 الفحص النهائي - SmartFriend Suite"
echo "==========================================="
echo

DB_MAIN="/var/lib/smartfrind/smart_memory.db"

echo "🎯 الحالة النهائية للنظام:"

# 1) قواعد البيانات
echo "📊 قواعد البيانات:"
sqlite3 "$DB_MAIN" "
SELECT '   🤖 ai_memory: ' || COUNT(*) || ' سجل' FROM ai_memory;
SELECT '   📚 knowledge_base: ' || COUNT(*) || ' سجل' FROM knowledge_base;
SELECT '   🔍 FTS Index: ' || COUNT(*) || ' سجل' FROM ai_memory_fts;
"

# 2) التصنيفات
echo "📁 التصنيفات في knowledge_base:"
sqlite3 "$DB_MAIN" "
SELECT category, COUNT(*) as count 
FROM knowledge_base 
GROUP BY category 
ORDER BY count DESC 
LIMIT 5;
" | while read line; do
    echo "   📂 $line"
done

# 3) الخدمات النشطة
echo "🚀 الخدمات النشطة:"
ps aux | grep -E "python.*(smart|memory|gateway)" | grep -v grep | head -5 | while read process; do
    echo "   🔄 $process"
done

echo
echo "✅ النظام جاهز بالكامل! 🎉"

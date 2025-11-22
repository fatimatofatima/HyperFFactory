#!/usr/bin/env bash
set -Eeuo pipefail

echo "🕷️ اختبار الـ Spider بعد الإصلاح..."
cd /opt/smartfriend-suite

# تشغيل الـ Spider المُصلح
echo "🚀 تشغيل smart_spider.py بعد الإصلاح..."
python3 bots/smart_spider.py --max-pages 2 --seeds-file bots/seeds.txt

# فحص النتائج
echo "🔍 النتائج بعد الزحف:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT '🤖 ai_memory: ' || COUNT(*) || ' سجل' FROM ai_memory;
SELECT '📚 knowledge_base: ' || COUNT(*) || ' سجل' FROM knowledge_base;
SELECT '📈 الزيادة في ai_memory: ' || (COUNT(*) - 783) FROM ai_memory;
"

# فحص آخر السجلات المضافة
echo "🆕 آخر السجلات في ai_memory:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT id, substr(user_input, 1, 50), substr(ai_response, 1, 50), category 
FROM ai_memory 
ORDER BY id DESC 
LIMIT 3;
"

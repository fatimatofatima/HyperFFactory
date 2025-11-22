#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🕷️ تشغيل نظام الزحف الحقيقي"
echo "==========================================="
echo

SUITE_DIR="/opt/smartfriend-suite"

cd "$SUITE_DIR"

# تشغيل الـ Spider الحقيقي من packages/ingest/
echo "🚀 تشغيل Spider Core من packages/ingest/..."
python3 packages/ingest/spider_core.py

# إذا كان فيه مشكلة، نجرب الـ Spider البديل
if [[ $? -ne 0 ]]; then
    echo "🔄 تجربة Spider البديل..."
    python3 bots/smart_spider.py
fi

# فحص النتائج
echo "🔍 فحص البيانات بعد الزحف..."
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT 'السجلات في ai_memory: ' || COUNT(*) FROM ai_memory;
SELECT 'السجلات في knowledge_base: ' || COUNT(*) FROM knowledge_base;
"

echo "✅ تشغيل الـ Spider اكتمل!"

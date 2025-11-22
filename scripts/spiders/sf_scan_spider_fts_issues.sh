#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔍 فحص مشاكل FTS في الـ Spider..."

cd /opt/smartfriend-suite

echo "📋 البحث عن إشارات لـ user_input في smart_spider.py:"
grep -n "user_input" bots/smart_spider.py || echo "✅ لا توجد إشارات مباشرة لـ user_input"

echo ""
echo "📋 البحث عن إشارات لـ ai_memory_fts:"
grep -n "ai_memory_fts" bots/smart_spider.py || echo "✅ لا توجد إشارات مباشرة لـ ai_memory_fts"

echo ""
echo "📋 فحص triggers في قاعدة البيانات:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT name, sql FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'ai_memory%';
"

echo ""
echo "🎯 حالة FTS الحالية:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT 'ai_memory: ' || COUNT(*) FROM ai_memory;
SELECT 'ai_memory_fts: ' || COUNT(*) FROM ai_memory_fts;
SELECT 'knowledge_base: ' || COUNT(*) FROM knowledge_base;
"

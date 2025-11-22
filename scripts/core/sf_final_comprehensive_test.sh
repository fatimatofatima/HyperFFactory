#!/usr/bin/env bash
set -Eeuo pipefail

echo "🏁 الاختبار النهائي الشامل لنظام المعرفة..."

echo ""
echo "1. 🔍 اختبار FTS مباشرة من SQLite:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT COUNT(*) AS fts_matches
FROM knowledge_base kb
JOIN ai_memory_fts ON ai_memory_fts.rowid = kb.ai_id
WHERE ai_memory_fts MATCH 'python programming';
"

echo ""
echo "2. 🕷️ اختبار Spider مع معالجة حقيقية:"
cd /opt/smartfriend-suite

# تشغيل بايثون عبر heredoc لتفادي مشاكل الاقتباسات داخل f-strings
timeout 30s python3 << 'PY'
import asyncio
import sys

sys.path.append('/opt/smartfriend-suite')

try:
    from bots.smart_spider import SmartSpider
except Exception as e:
    print(f"❌ فشل استيراد SmartSpider: {e}")
    raise SystemExit(1)

async def comprehensive_spider_test():
    success = False
    try:
        spider = SmartSpider()
        print("🚀 بدء اختبار Spider شامل...")

        text = "test spider functionality from final comprehensive test"
        result = await spider.process_input(text)

        print("✅ Spider processing succeeded, أول 200 حرف من المخرجات:")
        if result:
            preview = str(result)[:200].replace("\n", " ")
            print(preview)
        else:
            print("⚠️ لا توجد مخرجات (result فارغ).")

        success = True
    except Exception as e:
        print(f"❌ Spider error: {e}")
        success = False

    status = "PASS" if success else "FAIL"
    print(f"🎯 Spider test result: {status}")

asyncio.run(comprehensive_spider_test())
PY

echo ""
echo "3. 📊 التحقق من تكامل البيانات بعد الاختبار:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT 
    (SELECT COUNT(*) FROM ai_memory) as ai_memory_count,
    (SELECT COUNT(*) FROM ai_memory_fts) as fts_count,
    (SELECT COUNT(*) FROM knowledge_base) as kb_count;"

echo ""
echo "✅ اكتمل sf_final_comprehensive_test.sh"

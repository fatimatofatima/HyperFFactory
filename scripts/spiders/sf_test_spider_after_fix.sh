#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار Spider بعد إصلاح التريجرز..."

# تشغيل اختبار سريع للـ Spider
cd /opt/smartfriend-suite
timeout 20s python3 -c "
import asyncio
import sys
sys.path.append('/opt/smartfriend-suite')

async def test_spider():
    try:
        from bots.smart_spider import SmartSpider
        spider = SmartSpider()
        print('🚀 بدء اختبار Spider...')
        
        # اختبار معالجة مدخل بسيط
        result = await spider.process_input('test python programming')
        print(f'✅ Spider test successful: {result[:80]}...')
        
    except Exception as e:
        print(f'❌ Spider error: {e}')
        import traceback
        traceback.print_exc()

asyncio.run(test_spider())
" 2>&1

echo ""
echo "📊 فحص حالة FTS بعد الاختبار:"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT COUNT(*) as total_ai_memory FROM ai_memory;
SELECT COUNT(*) as total_fts FROM ai_memory_fts;
SELECT COUNT(*) as total_kb FROM knowledge_base;
"

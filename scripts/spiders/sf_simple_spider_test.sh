#!/usr/bin/env bash
set -Eeuo pipefail

echo "🧪 اختبار Spider مع البيانات الحالية..."

cd /opt/smartfriend-suite

# تشغيل Spider لفترة وجيزة مع مراقبة الأخطاء
timeout 30s python3 -c "
import sys
sys.path.append('/opt/smartfriend-suite')
from bots.smart_spider import SmartSpider
import asyncio

async def test_spider():
    spider = SmartSpider()
    print('✅ Spider initiated successfully')
    
    # محاولة معالجة مدخل بسيط
    try:
        result = await spider.process_input('test spider functionality')
        print(f'✅ Spider processing test: {result[:100]}...')
    except Exception as e:
        print(f'❌ Spider error: {e}')

asyncio.run(test_spider())
" 2>&1 | grep -E "(✅|❌|error|user_input|fts)" || echo "⚠️ No relevant output"

echo ""
echo "📊 فحص أي أخطاء حديثة في logs:"
journalctl -u smartfriend-spider --since "5 minutes ago" 2>/dev/null | grep -i "error\|fts\|user_input" || echo "✅ لا توجد أخطاء حديثة"

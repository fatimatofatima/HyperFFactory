#!/usr/bin/env bash
set -Eeuo pipefail

echo "🚀 تشغيل البوابة المحسنة المصححة..."

cd /opt/smartfriend-suite

# إيقاف أي عملية قديمة
echo "🛑 إيقاف العمليات القديمة على 8223..."
pkill -f "enhanced_unified_gateway" || true
sleep 2

# تشغيل البوابة المصححة
echo "🔧 تشغيل البوابة المحسنة المصححة..."
nohup python3 bots/app/smartfrind/enhanced_unified_gateway_fixed.py > /var/log/sf_enhanced_gateway_fixed.log 2>&1 &

echo "⏳ انتظار بدء التشغيل..."
sleep 5

# التحقق من التشغيل
echo "🔍 التحقق من التشغيل..."
if curl -s http://localhost:8223/health > /dev/null; then
    echo "✅ البوابة المحسنة المصححة شغالة على http://localhost:8223"
    echo "📊 حالة النظام:"
    curl -s http://localhost:8223/health | python3 -m json.tool
else
    echo "❌ فشل تشغيل البوابة المصححة"
    echo "📋 السجلات:"
    tail -10 /var/log/sf_enhanced_gateway_fixed.log
fi

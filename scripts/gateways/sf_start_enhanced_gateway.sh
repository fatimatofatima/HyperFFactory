#!/usr/bin/env bash
set -Eeuo pipefail

echo "تشغيل البوابة المحسنة مع نظام المعرفة..."

cd /opt/smartfriend-suite

# التأكد من وجود عميل المعرفة
if [ ! -f "sf_knowledge_client_complete.py" ] && [ -f "/root/sf_knowledge_client_complete.py" ]; then
    cp /root/sf_knowledge_client_complete.py sf_knowledge_client_complete.py
fi

# إيقاف أي عملية قديمة على 8223
PID_OLD=$(lsof -t -i:8223 || true)
if [ -n "$PID_OLD" ]; then
    echo "إيقاف العملية القديمة على 8223: $PID_OLD"
    kill "$PID_OLD" || true
    sleep 2
fi

# تشغيل البوابة في الخلفية
echo "تشغيل enhanced_unified_gateway.py على المنفذ 8223..."
nohup python3 bots/app/smartfrind/enhanced_unified_gateway.py >/var/log/sf_enhanced_gateway.log 2>&1 &

sleep 3

# فحص الصحة
echo "فحص /health على 8223..."
curl -s "http://localhost:8223/health" || echo "فشل الاتصال بالبوابة المحسنة"

echo "انتهى سكربت sf_start_enhanced_gateway.sh"

#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔍 فحص حالة جميع البوابات وإعادة تشغيلها إذا لزم الأمر..."

echo ""
echo "1. 📋 فحص العمليات الشغالة:"
echo "   🔍 بوابة البحث (8221):"
ps aux | grep -E "8221.*python" | grep -v grep || echo "   ❌ غير شغالة"
echo "   🎓 بوابة التعلم (8222):" 
ps aux | grep -E "8222.*python" | grep -v grep || echo "   ❌ غير شغالة"
echo "   🚀 البوابة المحسنة (8223):"
ps aux | grep -E "8223.*python" | grep -v grep || echo "   ❌ غير شغالة"

echo ""
echo "2. 🛑 إيقاف جميع البوابات:"
pkill -f "8221" || true
pkill -f "8222" || true  
pkill -f "8223" || true
pkill -f "sf_update_unified_gateway.py" || true
pkill -f "sf_update_learning_gateway.py" || true
sleep 3

echo ""
echo "3. 🚀 إعادة تشغيل البوابات الأساسية:"
echo "   🔍 تشغيل بوابة البحث (8221)..."
cd /opt/smartfriend-suite
nohup python3 /root/sf_update_unified_gateway.py > /var/log/sf_knowledge_gateway.log 2>&1 &

echo "   🎓 تشغيل بوابة التعلم (8222)..."
nohup python3 /root/sf_update_learning_gateway.py > /var/log/sf_learning_gateway.log 2>&1 &

echo "   🚀 تشغيل البوابة المحسنة (8223)..."
nohup python3 bots/app/smartfrind/enhanced_unified_gateway_fixed.py > /var/log/sf_enhanced_gateway_fixed.log 2>&1 &

echo ""
echo "⏳ انتظار بدء التشغيل..."
sleep 5

echo ""
echo "4. ✅ التحقق من التشغيل:"
echo "   🔍 بوابة البحث (8221):"
if curl -s http://localhost:8221/health > /dev/null 2>&1; then
    echo "      ✅ شغالة - http://localhost:8221/health"
else
    echo "      ❌ غير شغالة"
    echo "      📋 سجلات بوابة البحث:"
    tail -5 /var/log/sf_knowledge_gateway.log 2>/dev/null || echo "        ℹ️ لا توجد سجلات"
fi

echo "   🎓 بوابة التعلم (8222):"
if curl -s http://localhost:8222/health > /dev/null 2>&1; then
    echo "      ✅ شغالة - http://localhost:8222/health" 
else
    echo "      ❌ غير شغالة"
    echo "      📋 سجلات بوابة التعلم:"
    tail -5 /var/log/sf_learning_gateway.log 2>/dev/null || echo "        ℹ️ لا توجد سجلات"
fi

echo "   🚀 البوابة المحسنة (8223):"
if curl -s http://localhost:8223/health > /dev/null 2>&1; then
    echo "      ✅ شغالة - http://localhost:8223/health"
    curl -s http://localhost:8223/health | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'        • الخدمة: {data.get(\"service\", \"N/A\")}')
print(f'        • نظام المعرفة: {data.get(\"knowledge_system\", \"N/A\")}')
"
else
    echo "      ❌ غير شغالة"
    echo "      📋 سجلات البوابة المحسنة:"
    tail -5 /var/log/sf_enhanced_gateway_fixed.log 2>/dev/null || echo "        ℹ️ لا توجد سجلات"
fi

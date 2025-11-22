#!/usr/bin/env bash
set -Eeuo pipefail

echo "🚀 تشغيل البوابات المحدثة مع knowledge_base..."

# إيقاف البوابات القديمة إذا كانت شغالة
pkill -f "unified_gateway.py" || true
pkill -f "ai_learning_gateway.py" || true
pkill -f "sf_update_unified_gateway.py" || true
pkill -f "sf_update_learning_gateway.py" || true
sleep 2

# تشغيل البوابات المحدثة
echo "🔧 تشغيل Unified Gateway (المعرفة)..."
python3 /root/sf_update_unified_gateway.py &

echo "🎓 تشغيل AI Learning Gateway (المعرفة)..."
python3 /root/sf_update_learning_gateway.py &

sleep 3

echo "✅ البوابات المحدثة شغالة الآن!"
echo "📊 فحص التشغيل:"
ps aux | grep -E "(sf_update_unified_gateway|sf_update_learning_gateway)" | grep -v grep

echo ""
echo "🌐 الواجهات المتاحة:"
echo "   http://localhost:8221/docs - Unified Gateway (المعرفة)"
echo "   http://localhost:8222/docs - Learning Gateway (المعرفة)"

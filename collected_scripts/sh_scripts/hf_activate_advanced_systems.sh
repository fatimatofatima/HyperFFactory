#!/bin/bash
echo "🚀 تفعيل الأنظمة المتقدمة في Hyper Factory"
echo "=========================================="

# 1. تفعيل محرك الأنماط
echo "🔍 تفعيل Patterns Engine..."
python3 agents/patterns_engine/patterns_engine.py

# 2. تفعيل محرك الجودة  
echo "📊 تفعيل Quality Engine..."
python3 agents/quality_engine/quality_engine.py

# 3. تحديث التدقيق المتقدم
echo "🔄 تحديث التدقيق المتقدم..."
python3 advanced_audit.py

# 4. عرض النتائج
echo ""
echo "📈 النتائج النهائية:"
echo "===================="
cat reports/advanced_audit.txt | grep -A 5 "Executive Summary"

echo ""
echo "✅ تم تفعيل الأنظمة المتقدمة بنجاح!"

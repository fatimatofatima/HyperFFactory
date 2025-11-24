#!/bin/bash
echo "=========================================="
echo "   🔍 فحص متقدم للنظام"
echo "=========================================="

# فحص العمليات
echo "🔄 العمليات النشطة:"
ps aux | grep -E "smart|ffactory|python" | head -15

echo ""
echo "📊 فحص قاعدة البيانات:"
if [ -f "/var/lib/smartfrind/smart_memory.db" ]; then
    echo "✅ قاعدة الذاكرة موجودة"
    sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM ai_memory;" 2>/dev/null || echo "❌ خطأ في فحص قاعدة البيانات"
else
    echo "❌ قاعدة الذاكرة غير موجودة"
fi

echo ""
echo "📋 فحص السكريبتات:"
find /opt -name "*.sh" -type f 2>/dev/null | head -10
for script in $(find /opt -name "*.sh" -type f 2>/dev/null | head -5); do
    echo "🔍 $script - $(ls -la $script | awk '{print $1, $3, $4}')"
done

echo ""
echo "📁 فحص هيكل smartfriend-suite:"
if [ -d "/opt/smartfriend-suite" ]; then
    find /opt/smartfriend-suite -maxdepth 2 -type d | head -20
fi

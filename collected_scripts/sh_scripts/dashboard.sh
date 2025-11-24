#!/bin/bash

echo "================================================"
echo "   🎛️  لوحة تحكم النظام"
echo "================================================"
echo "الوقت: $(date)"

# معلومات النظام
echo ""
echo "🖥️  حالة النظام:"
echo "Uptime: $(uptime -p)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"

# الموارد
echo ""
echo "💾 الموارد:"
echo "Memory: $(free -h | grep Mem | awk '{print $3 \"/\" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 \"/\" $2 \" (\" $5 \")\"}')"

# SmartFriend Status
echo ""
echo "🤖 حالة SmartFriend:"
if pgrep -f "smart\|friend\|ffactory" > /dev/null; then
    echo "✅ الخدمات نشطة"
    pgrep -f "smart\|friend\|ffactory" | head -5
else
    echo "❌ لا توجد خدمات نشطة"
fi

# قاعدة البيانات
if [ -f "/var/lib/smartfrind/smart_memory.db" ]; then
    count=$(sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM ai_memory;" 2>/dev/null || echo "0")
    echo "📚 قاعدة المعرفة: $count سجل"
else
    echo "📚 قاعدة المعرفة: غير موجودة"
fi

echo ""
echo "✅ اللوحة جاهزة"

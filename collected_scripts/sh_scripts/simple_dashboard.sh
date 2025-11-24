#!/bin/bash
echo "=================================================="
echo "   🎛️  Dashboard مبسط"
echo "=================================================="

# حالة النظام
echo "🖥️  النظام:"
uptime
echo "💾 الذاكرة:"
free -h | grep Mem
echo "💿 التخزين:"
df -h / | tail -1

# حالة SmartFriend
echo ""
echo "🤖 SmartFriend:"
if [ -f "/var/lib/smartfrind/smart_memory.db" ]; then
    count=$(sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM ai_memory;" 2>/dev/null || echo "0")
    echo "📚 قاعدة المعرفة: $count سجل"
else
    echo "📚 قاعدة المعرفة: غير موجودة"
fi

# الخدمات
echo ""
echo "🔧 الخدمات:"
running=$(systemctl list-units --type=service --state=running | grep -c "smart")
total=$(systemctl list-unit-files | grep -c "smart")
echo "🟢 $running/$total خدمة نشطة"

# البوابات
echo ""
echo "🌐 البوابات:"
ports=("8000" "8170" "8211" "8214" "8220")
for port in "${ports[@]}"; do
    if netstat -tulpn | grep -q ":$port "; then
        echo "✅ :$port - نشط"
    else
        echo "❌ :$port - غير نشط"
    fi
done

echo ""
echo "🚀 استخدم: ./scan_opt.sh أو ./system_check.sh للمزيد"

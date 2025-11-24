#!/bin/bash
echo "=========================================="
echo "   🔍 فحص سريع للنظام"
echo "=========================================="
echo "الوقت: $(date)"
echo "المستخدم: $(whoami)"
echo "النظام: $(hostname)"
echo "=========================================="

echo ""
echo "📁 محتويات /opt:"
ls -la /opt/ | head -10

echo ""
echo "🤖 فحص SmartFriend:"
if [ -d "/opt/smartfriend-suite" ]; then
    echo "✅ مجلد smartfriend-suite موجود"
    find /opt/smartfriend-suite -name "*.db" -type f 2>/dev/null | head -5
else
    echo "❌ مجلد smartfriend-suite غير موجود"
fi

echo ""
echo "🔧 الخدمات النشطة:"
systemctl list-units --type=service --state=running | grep -E "smart|ffactory" | head -10

echo ""
echo "🌐 البوابات النشطة:"
netstat -tulpn | grep -E ":(8000|8170|8211|8214|8220|8221|8222)" | head -10

echo ""
echo "💾 استخدام الموارد:"
free -h | grep Mem
df -h / /opt | tail -1

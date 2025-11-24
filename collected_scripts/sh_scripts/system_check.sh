#!/bin/bash
echo "=================================================="
echo "   🔍 فحص النظام بشكل عملي"
echo "=================================================="
echo "الوقت: $(date)"

echo "1. الخدمات النشطة:"
systemctl list-units --type=service --state=running | grep -E "smart|ffactory" | head -10

echo ""
echo "2. العمليات النشطة:"
ps aux | grep -E "smart|ffactory|python" | head -10

echo ""
echo "3. البوابات النشطة:"
netstat -tulpn | grep -E ":(8000|8170|8211|8214|8220|8221|8222)" | head -10

echo ""
echo "4. استخدام الموارد:"
free -h
echo ""
df -h / /opt

echo ""
echo "✅ تم الفحص بنجاح"

#!/bin/bash
echo "=== حالة خدمات SmartFriend ==="
echo ""

echo "✅ الخدمات الشغالة:"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager --no-legend | grep -E "(running|exited)" | head -10

echo ""
echo "❌ الخدمات الفاشلة:"
systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-pager --no-legend

echo ""
echo "🔄 الخدمات المعطلة:"
systemctl list-units "sf-*" "smartfrind-*" --state=inactive --no-pager --no-legend | head -10

echo ""
echo "📊 المنافذ النشطة:"
netstat -tlnp | grep -E ":(8210|8214|8220|8383|8390)" | head -10

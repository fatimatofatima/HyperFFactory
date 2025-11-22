#!/bin/bash
echo "🔧 تفعيل الخدمات الحرجة - الإصدار الفوري"

# 1. إصلاح وتفعيل sf-memory
echo "🧠 تفعيل Memory API..."
sudo systemctl stop sf-memory.service
sudo systemctl daemon-reload
sudo systemctl start sf-memory.service
sleep 3

if systemctl is-active --quiet sf-memory.service; then
    echo "✅ sf-memory.service - نشط الآن"
else
    echo "❌ فشل تفعيل sf-memory - فحص الأخطاء:"
    sudo journalctl -u sf-memory.service -n 5 --no-pager
fi

# 2. إصلاح وتفعيل sf-web
echo "🌐 تفعيل الواجهة..."
sudo systemctl stop sf-web.service
sudo systemctl daemon-reload
sudo systemctl start sf-web.service
sleep 3

if systemctl is-active --quiet sf-web.service; then
    echo "✅ sf-web.service - نشط الآن"
else
    echo "❌ فشل تفعيل sf-web - فحص الأخطاء:"
    sudo journalctl -u sf-web.service -n 5 --no-pager
fi

# 3. التحقق من البورتات
echo "🔌 التحقق من البورتات..."
ss -tulpn | grep -E '(:8214|:8390)' || echo "⚠️  البورتات غير نشطة بعد"

echo "🎯 تم الانتهاء من التفغيل الفوري"

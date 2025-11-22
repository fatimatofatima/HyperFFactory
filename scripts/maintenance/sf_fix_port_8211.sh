#!/bin/bash
echo "========================================"
echo " 🔧 إصلاح مشكلة البورت 8211"
echo "========================================"

echo "1. إيقاف العملية التي تحتل البورت 8211..."
sudo kill -TERM 341896
sleep 2

echo "2. التحقق من تحرير البورت..."
if ss -tlnp | grep -q ':8211 '; then
    echo "❌ البورت 8211 ما زال مشغولاً"
    exit 1
else
    echo "✅ البورت 8211 تم تحريره بنجاح"
fi

echo "3. تشغيل sf-core.service..."
sudo systemctl start sf-core.service
sleep 3

echo "4. التحقق من حالة الخدمة..."
sudo systemctl status sf-core.service --no-pager

echo "5. اختبار الخدمة..."
if curl -s http://127.0.0.1:8211/health >/dev/null 2>&1; then
    echo "✅ sf-core.service يعمل بنجاح على البورت 8211"
else
    echo "❌ فشل في الاتصال بالخدمة"
fi

echo "========================================"

#!/bin/bash
echo "🚨 تنظيف طارئ للمساحة..."

# حذف الملفات المؤقتة
echo "🗑️ حذف الملفات المؤقتة..."
find /tmp -name "*.tmp" -type f -delete 2>/dev/null
find /root -name "*.log" -size +100M -delete 2>/dev/null

# تنظيف ذاكرة التخزين المؤقت
echo "🧹 تنظيف الذاكرة المؤقتة..."
sync && echo 3 > /proc/sys/vm/drop_caches

# حذف النسخ القديمة
echo "📦 حذف النسخ القديمة..."
rm -rf /root/hyper-factory_broken_* 2>/dev/null
rm -rf /root/hyper-factory-merged/_hash_* 2>/dev/null

# تقليص ملفات السجلات الكبيرة
echo "📋 تقليص السجلات..."
find /root -name "*.log" -exec truncate -s 10M {} \; 2>/dev/null

echo "✅ تم التنظيف الطارئ"

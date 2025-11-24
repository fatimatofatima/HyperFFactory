#!/bin/bash
echo "🔍 البحث عن الملفات الكبيرة"
echo "=========================="

# البحث عن الملفات الأكبر من 100MB
echo "📁 الملفات الأكبر من 100MB:"
find /root -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -20

# البحث عن الملفات الأكبر من 50MB
echo "📁 الملفات الأكبر من 50MB:"
find /root -type f -size +50M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -30

# أكبر 10 مجلدات
echo "📦 أكبر 10 مجلدات:"
du -h /root/* 2>/dev/null | sort -rh | head -10

# قواعد البيانات الكبيرة
echo "🗃️ قواعد البيانات الكبيرة:"
find /root -name "*.db" -size +10M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr

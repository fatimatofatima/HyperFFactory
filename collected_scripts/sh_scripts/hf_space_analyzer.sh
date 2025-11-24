#!/bin/bash
echo "📊 محلل المساحة التفصيلي"

# أكبر 20 مجلد
echo "🏆 أكبر 20 مجلد:"
du -h /root/* 2>/dev/null | sort -rh | head -20

# أكبر 20 ملف
echo "📁 أكبر 20 ملف:"
find /root -type f -exec du -h {} + 2>/dev/null | sort -rh | head -20

# تحليل hyper-factory
echo "🏭 تحليل Hyper-Factory:"
du -h /root/hyper-factory* 2>/dev/null | sort -rh

# قواعد البيانات الكبيرة
echo "🗃️ قواعد البيانات الكبيرة:"
find /root -name "*.db" -exec du -h {} + 2>/dev/null | sort -rh | head -10

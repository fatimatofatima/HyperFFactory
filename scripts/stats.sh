#!/bin/bash
echo "📊 إحصائيات HyperFFactory"
echo "========================="
for category in /root/HyperFFactory/scripts/*/; do
    count=$(find "$category" -name "*.sh" -o -name "*.py" | wc -l)
    echo "📁 $(basename "$category"): $count سكريبت"
done
total=$(find /root/HyperFFactory/scripts -name "*.sh" -o -name "*.py" | wc -l)
echo "🎯 الإجمالي: $total سكريبت"

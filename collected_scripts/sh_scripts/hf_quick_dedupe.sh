#!/bin/bash
echo "⚡ حذف تكرار سريع - 6 أنوية"
echo "=========================="

SRC="/root/hyper-factory-merged"
DST="/root/hyper-factory-clean-fast"

rm -rf "$DST"
mkdir -p "$DST"

# Python فريد
echo "🐍 Python فريد..."
find "$SRC" -name "*.py" -type f | head -10000 | \
xargs -P 6 -I {} md5sum {} | sort -u -k1,1 | \
awk '{print $2}' | xargs -I {} -P 6 cp {} "$DST/python/" 2>/dev/null

# Shell فريد
echo "🐚 Shell فريد..."
find "$SRC" -name "*.sh" -type f | head -5000 | \
xargs -P 6 -I {} md5sum {} | sort -u -k1,1 | \
awk '{print $2}' | xargs -I {} -P 6 cp {} "$DST/scripts/" 2>/dev/null

echo "📊 النتيجة:"
echo "• Python: $(find "$DST/python" -name "*.py" 2>/dev/null | wc -l) ملف"
echo "• Shell: $(find "$DST/scripts" -name "*.sh" 2>/dev/null | wc -l) ملف" 
echo "• الإجمالي: $(find "$DST" -type f | wc -l) ملف"

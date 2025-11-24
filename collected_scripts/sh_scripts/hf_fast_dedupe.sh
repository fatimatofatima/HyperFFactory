#!/bin/bash
echo "⚡ حذف تكرار سريع - 6 أنوية"
echo "=========================="

SRC="/root/hyper-factory-merged"
DST="/root/hyper-factory-unique-fast"

rm -rf "$DST"
mkdir -p "$DST"

# دالة سريعة باستخدام fdupes (إذا موجود)
if command -v fdupes &> /dev/null; then
    echo "🔍 استخدام fdupes للبحث عن التكرار..."
    fdupes -r "$SRC" > /tmp/duplicates.txt
    echo "✅ تم العثور على $(grep -c "^$" /tmp/duplicates.txt) مجموعة تكرار"
fi

# طريقة سريعة باستخدام parallel و md5sum
echo "🐍 معالجة Python بالتوازي..."
find "$SRC" -name "*.py" -type f | parallel -j6 md5sum | sort -u -k1,1 | \
awk '{print $2}' | head -5000 | xargs -I {} cp {} "$DST/python/" 2>/dev/null

echo "🐚 معالجة Shell بالتوازي..."
find "$SRC" -name "*.sh" -type f | parallel -j6 md5sum | sort -u -k1,1 | \
awk '{print $2}' | head -2000 | xargs -I {} cp {} "$DST/scripts/" 2>/dev/null

echo "📊 النتيجة:"
echo "• Python: $(find "$DST/python" -name "*.py" 2>/dev/null | wc -l) ملف"
echo "• Shell: $(find "$DST/scripts" -name "*.sh" 2>/dev/null | wc -l) ملف"
echo "• الإجمالي: $(find "$DST" -type f | wc -l) ملف"

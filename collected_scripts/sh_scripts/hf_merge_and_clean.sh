#!/bin/bash
echo "🔄 دمج وتنظيف ذكي - 6 أنوية"

SRC_DIRS=(
    "/root/hyper-factory-merged"
    "/root/hyper-factory-unified" 
    "/root/hyper-factory-unique-final"
)
DEST="/root/hyper-factory-final"
LOG="/root/merge_clean.log"

rm -rf "$DEST"
mkdir -p "$DEST"

echo "🔍 تحليل الملفات الفريدة..."

# جمع جميع الملفات من المصادر
for dir in "${SRC_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        find "$dir" -type f \( -name "*.py" -o -name "*.sh" \) >> /tmp/all_sources.txt
    fi
done

# استخدام parallel لحساب الهاش
echo "🧮 حساب الهاش (6 أنوية)..."
cat /tmp/all_sources.txt | head -20000 | parallel -j6 --eta md5sum | \
sort -u -k1,1 > /tmp/unique_hashes.txt

# نسخ الملفات الفريدة
echo "📥 نسخ الملفات الفريدة..."
awk '{print $2}' /tmp/unique_hashes.txt | \
parallel -j6 "cp --parents {} $DEST/ 2>/dev/null"

# الإحصائيات النهائية
TOTAL_FILES=$(cat /tmp/all_sources.txt | wc -l)
UNIQUE_FILES=$(cat /tmp/unique_hashes.txt | wc -l)

echo "📊 النتائج:"
echo "• إجمالي الملفات: $TOTAL_FILES"
echo "• الملفات الفريدة: $UNIQUE_FILES" 
echo "• نسبة التكرار: $(( (TOTAL_FILES - UNIQUE_FILES) * 100 / TOTAL_FILES ))%"
echo "• المسار النهائي: $DEST"

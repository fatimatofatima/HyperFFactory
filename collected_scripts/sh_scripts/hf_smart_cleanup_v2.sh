#!/bin/bash
echo "🧹 تنظيف ذكي محسن - 6 أنوية"

SRC="/root/hyper-factory-merged"
DST="/root/hyper-factory-clean"
LOG="/root/cleanup.log"

rm -rf "$DST"
mkdir -p "$DST"

# وظيفة حساب الهاش السريع
fast_hash() {
    parallel -j6 "md5sum {}" ::: "$@" 2>/dev/null
}

# جمع الملفات الفريدة
echo "🔍 جمع الملفات الفريدة..."
find "$SRC" -type f \( -name "*.py" -o -name "*.sh" \) > /tmp/all_files.txt

# معالجة بالتوازي
cat /tmp/all_files.txt | head -10000 | parallel -j6 --progress md5sum | \
sort -u -k1,1 | awk '{print $2}' | \
parallel -j6 "cp {} $DST/ 2>/dev/null"

echo "📊 النتيجة: $(find "$DST" -type f | wc -l) ملف فريد"

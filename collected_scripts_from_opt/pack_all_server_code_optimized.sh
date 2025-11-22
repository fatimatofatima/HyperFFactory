#!/usr/bin/env bash
set -Eeuo pipefail

MAX_MB="${1:-5}"                                   # حد أصغر 5MB
OUT_DIR="${2:-/root/all_server_code_optimized}"    # مجلد إخراج جديد
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OUT_DIR"
OUT_ARCHIVE="${OUT_DIR}/server_code_optimized_${TS}.tar.zst"
MANIFEST="${OUT_DIR}/server_code_optimized_${TS}.manifest.tsv"

echo "🔍 Searching for REAL code files (excluding large data files)..."

# استبعاد الملفات الكبيرة والبيانات (ليس أكواد)
find /root /opt /home /var/www /usr/local /etc -type f \
  \( -name "*.py" -o -name "*.sh" -o -name "*.js" -o -name "*.ts" -o \
     -name "*.go" -o -name "*.rs" -o -name "*.rb" -o -name "*.php" -o \
     -name "*.java" -o -name "*.c" -o -name "*.cpp" -o \
     -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o \
     -name "Dockerfile" -o -name "docker-compose*.yml" -o \
     -name "Makefile" \) \
  ! -name "*.min.js" ! -name "*report*" ! -name "*analysis*" ! -name "*hits.txt" ! -name "*refs.txt" \
  -size -"${MAX_MB}"M 2>/dev/null > /tmp/clean_code.list

FILE_COUNT=$(wc -l < /tmp/clean_code.list)
echo "📁 Found $FILE_COUNT CLEAN code files"

if [[ $FILE_COUNT -eq 0 ]]; then
    echo "❌ No code files found"
    exit 1
fi

# الmanifest
while IFS= read -r file; do
    size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    printf "%s\t%s\n" "$file" "$size"
done < /tmp/clean_code.list > "$MANIFEST"

# الأرشيف
echo "📦 Creating optimized archive..."
tar -T /tmp/clean_code.list -cf - | zstd -19 -o "$OUT_ARCHIVE"

rm -f /tmp/clean_code.list

echo ""
echo "✅ OPTIMIZED SERVER CODE COLLECTION COMPLETE!"
echo "📦 Archive: $OUT_ARCHIVE"
echo "📄 Manifest: $MANIFEST"
echo "📁 Total Files: $FILE_COUNT"
echo "💾 Size: $(du -h "$OUT_ARCHIVE" | cut -f1)"

# إحصائيات إضافية
echo ""
echo "📊 FILE TYPE BREAKDOWN:"
file -b /tmp/clean_code.list | cut -d'/' -f1 | sort | uniq -c | sort -nr

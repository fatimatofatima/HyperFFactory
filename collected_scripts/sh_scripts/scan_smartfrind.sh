#!/bin/bash

target="/opt/smartfrind"
report="smartfrind_scan_$(date +%Y%m%d_%H%M%S).txt"

echo "📁 فحص المجلد: $target" > "$report"
echo "⏰ وقت الفحص: $(date '+%Y-%m-%d %H:%M:%S')" >> "$report"
echo "----------------------------------------" >> "$report"

find "$target" -type f \( -name "*.py" -o -name "*.sh" \) | while read -r file; do
    size=$(stat -c%s "$file" 2>/dev/null || echo "N/A")
    mod=$(date -r "$file" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "N/A")
    perm=$(stat -c%A "$file" 2>/dev/null || echo "N/A")
    echo "$mod | $size bytes | $perm | $file" >> "$report"
done

echo "----------------------------------------" >> "$report"
echo "📊 Total files: $(grep -c 'bytes' "$report")" >> "$report"

echo "✅ تم حفظ التقرير في: $report"

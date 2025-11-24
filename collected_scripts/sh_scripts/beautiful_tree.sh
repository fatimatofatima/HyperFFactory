#!/usr/bin/env bash
set -Eeuo pipefail

target="/opt/smartfrind"
report="beautiful_tree_$(date +%Y%m%d_%H%M%S).txt"

echo "🌳 الشجرة الكاملة مع التنسيق الجميل" > "$report"
echo "📅 $(date '+%Y-%m-%d %H:%M:%S')" >> "$report"
echo "=============================================" >> "$report"

show_tree() {
    local dir="$1"
    local indent="$2"

    # اسم وحجم المجلد
    local dir_name
    dir_name=$(basename "$dir")
    local dir_size
    dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    echo "${indent}📁 $dir_name/ [$dir_size]" >> "$report"

    # ===== الملفات في هذا المستوى (أكبر 10 فقط) =====
    local count=0
    while IFS= read -r -d '' file; do
        local size fname
        size=$(du -sh "$file" 2>/dev/null | cut -f1)
        fname=$(basename "$file")
        echo "${indent}   ├── 📄 $fname [$size]" >> "$report"
        count=$((count + 1))
        if [ "$count" -ge 10 ]; then
            break
        fi
    done < <(find "$dir" -maxdepth 1 -type f -print0 2>/dev/null)

    local total_files
    total_files=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
    if [ "$total_files" -gt "$count" ]; then
        echo "${indent}   └── ... ($((total_files - count)) ملفات أخرى)" >> "$report"
    fi

    # ===== المجلدات الفرعية =====
    local subdirs=()
    while IFS= read -r -d '' sub; do
        subdirs+=("$sub")
    done < <(find "$dir" -maxdepth 1 -type d ! -path "$dir" -print0 2>/dev/null | sort -z)

    local idx=0
    local last=$(( ${#subdirs[@]} - 1 ))

    for sub in "${subdirs[@]}"; do
        [ -z "$sub" ] && continue
        local conn="├──"
        [ "$idx" -eq "$last" ] && conn="└──"
        echo "${indent}   $conn" >> "$report"
        show_tree "$sub" "${indent}   "
        idx=$((idx + 1))
    done
}

echo "💾 المساحة الإجمالية: $(du -sh "$target" 2>/dev/null | cut -f1)" >> "$report"
echo "" >> "$report"

show_tree "$target" ""

echo "" >> "$report"
echo "✅ تم حفظ التقرير في: $report" >> "$report"

# طباعة عينة في الشاشة
echo "✅ تم حفظ التقرير في: $report"
echo "📋 أول 80 سطر:"
head -80 "$report"

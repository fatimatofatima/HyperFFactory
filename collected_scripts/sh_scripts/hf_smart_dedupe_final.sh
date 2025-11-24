#!/bin/bash
set -euo pipefail

echo "🧹 حذف تكرار ذكي بالهاش - 6 أنوية"
echo "================================"

SRC="/root/hyper-factory-merged"
DST="/root/hyper-factory-unique-final"
LOG="/root/dedupe_final.log"

rm -rf "$DST"
mkdir -p "$DST"
> "$LOG"

echo "🔍 بدء المعالجة: $(date)" | tee -a "$LOG"

# دالة سريعة لحساب MD5
fast_md5() {
    local file="$1"
    md5sum "$file" 2>/dev/null | cut -d' ' -f1
}

# معالجة Python بالتوازي
echo "🐍 معالجة ملفات Python..." | tee -a "$LOG"
find "$SRC" -name "*.py" -type f -print0 | \
xargs -0 -P 6 -I {} bash -c '
    file="{}"
    hash=$(md5sum "$file" 2>/dev/null | cut -d" " -f1)
    if [[ -n "$hash" ]]; then
        echo "$hash:$file"
    fi
' | sort -u -t: -k1,1 | head -10000 | \
while IFS=: read -r hash file; do
    if [[ ! -f "$DST/python/${hash}_$(basename "$file")" ]]; then
        mkdir -p "$DST/python"
        cp "$file" "$DST/python/${hash}_$(basename "$file")" 2>/dev/null && \
        echo "✅ Python: $(basename "$file")" >> "$LOG"
    fi
done

# معالجة Shell بالتوازي  
echo "🐚 معالجة سكربتات Shell..." | tee -a "$LOG"
find "$SRC" -name "*.sh" -type f -print0 | \
xargs -0 -P 6 -I {} bash -c '
    file="{}"
    hash=$(md5sum "$file" 2>/dev/null | cut -d" " -f1)
    if [[ -n "$hash" ]]; then
        echo "$hash:$file"
    fi
' | sort -u -t: -k1,1 | head -5000 | \
while IFS=: read -r hash file; do
    if [[ ! -f "$DST/scripts/${hash}_$(basename "$file")" ]]; then
        mkdir -p "$DST/scripts"
        cp "$file" "$DST/scripts/${hash}_$(basename "$file")" 2>/dev/null && \
        echo "✅ Shell: $(basename "$file")" >> "$LOG"
    fi
done

# معالجة ملفات التكوين
echo "⚙️ معالجة ملفات التكوين..." | tee -a "$LOG"
for ext in json yaml yml; do
    find "$SRC" -name "*.$ext" -type f -print0 2>/dev/null | \
    xargs -0 -P 6 -I {} bash -c '
        file="{}"
        hash=$(md5sum "$file" 2>/dev/null | cut -d" " -f1)
        if [[ -n "$hash" ]]; then
            echo "$hash:$file"
        fi
    ' | sort -u -t: -k1,1 | head -1000 | \
    while IFS=: read -r hash file; do
        if [[ ! -f "$DST/config/${hash}_$(basename "$file")" ]]; then
            mkdir -p "$DST/config"
            cp "$file" "$DST/config/${hash}_$(basename "$file")" 2>/dev/null && \
            echo "✅ Config: $(basename "$file")" >> "$LOG"
        fi
    done
done

# نسخ الهياكل الأساسية
echo "📁 نسخ الهياكل الأساسية..." | tee -a "$LOG"
cp -r "/root/hyper-factory/stack" "$DST/" 2>/dev/null
cp -r "/root/hyper-factory/apps" "$DST/" 2>/dev/null
cp -r "/root/hyper-factory/data_lakehouse" "$DST/data/" 2>/dev/null

# إنشاء التقرير النهائي
echo "🎉 اكتملت عملية حذف التكرار: $(date)" | tee -a "$LOG"
echo "📊 الإحصائيات النهائية:" | tee -a "$LOG"
echo "   • Python: $(find "$DST/python" -name "*.py" 2>/dev/null | wc -l) ملف" | tee -a "$LOG"
echo "   • Shell: $(find "$DST/scripts" -name "*.sh" 2>/dev/null | wc -l) ملف" | tee -a "$LOG"
echo "   • Config: $(find "$DST/config" -type f 2>/dev/null | wc -l) ملف" | tee -a "$LOG"
echo "   • إجمالي: $(find "$DST" -type f | wc -l) ملف" | tee -a "$LOG"
echo "   • الحجم: $(du -sh "$DST" | cut -f1)" | tee -a "$LOG"

echo "✅ تم الانتهاء! التفاصيل في: $LOG"

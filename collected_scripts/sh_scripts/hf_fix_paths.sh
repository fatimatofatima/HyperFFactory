#!/bin/bash
echo "🔧 إصلاح مسارات الملفات..."
find /root/hyper-factory* -name "*أرشيف*" -type d | while read dir; do
    new_dir=$(echo "$dir" | sed 's/أرشيف/archive/g')
    echo "إصلاح: $dir -> $new_dir"
    mv "$dir" "$new_dir" 2>/dev/null
done

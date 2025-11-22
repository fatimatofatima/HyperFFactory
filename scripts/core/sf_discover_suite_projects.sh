#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🗂️  SmartFriend Suite - Projects Discovery"
echo "==========================================="
echo

SUITE_DIR="/opt/smartfriend-suite"

if [[ ! -d "$SUITE_DIR" ]]; then
    echo "❌ smartfriend-suite not found!"
    exit 1
fi

echo "🔍 Scanning for projects in $SUITE_DIR:"

# البحث عن مشاريع Python
find "$SUITE_DIR" -name "*.py" -type f | head -30 | while read py_file; do
    dir=$(dirname "$py_file")
    base_dir=$(basename "$dir")
    
    # إذا كان الملف في مجلد مشروع (ليس مجرد ملف عشوائي)
    if [[ "$dir" != "$SUITE_DIR" ]]; then
        echo "   🐍 $base_dir/$(basename "$py_file")"
        
        # محاولة اكتشاف إذا كان main file
        if grep -q "if __name__.*__main__" "$py_file" 2>/dev/null || 
           [[ "$(basename "$py_file")" == "main.py" ]] || 
           [[ "$(basename "$py_file")" == "app.py" ]]; then
            echo "      🎯 MAIN FILE DETECTED"
        fi
    fi
done

echo
echo "📁 Directory structure:"
find "$SUITE_DIR" -maxdepth 2 -type d | while read dir; do
    if [[ "$dir" != "$SUITE_DIR" ]]; then
        py_count=$(find "$dir" -name "*.py" | wc -l)
        if [[ $py_count -gt 0 ]]; then
            echo "   📂 $(basename "$dir") - $py_count Python files"
        fi
    fi
done

echo
echo "📋 Configuration files:"
find "$SUITE_DIR" -name "requirements.txt" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" | head -10 | while read config; do
    echo "   ⚙️  $config"
done

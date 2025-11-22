#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🔍 SmartFriend Projects Comparison"
echo "==========================================="
echo

BASE_DIRS=("/opt/smartfrind" "/opt/smartfriend-suite")

for base_dir in "${BASE_DIRS[@]}"; do
    if [[ -d "$base_dir" ]]; then
        echo "📁 $base_dir:"
        echo "   📊 Size: $(du -sh "$base_dir" | cut -f1)"
        echo "   📋 Python files: $(find "$base_dir" -name "*.py" | wc -l)"
        echo "   🗂️  Main directories:"
        find "$base_dir" -maxdepth 1 -type d | head -10 | while read dir; do
            if [[ "$dir" != "$base_dir" ]]; then
                echo "      📁 $(basename "$dir")"
            fi
        done
        echo
    else
        echo "❌ $base_dir: NOT FOUND"
        echo
    fi
done

# فحص المشاريع في smartfriend-suite
if [[ -d "/opt/smartfriend-suite" ]]; then
    echo "🔍 Projects in smartfriend-suite:"
    find "/opt/smartfriend-suite" -maxdepth 2 -name "*.py" -o -name "*.md" -o -name "requirements.txt" | head -20 | while read item; do
        echo "   📄 $item"
    done
fi

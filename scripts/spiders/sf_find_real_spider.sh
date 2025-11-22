#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🕷️ Finding the Real Spider System"
echo "==========================================="
echo

SUITE_DIR="/opt/smartfriend-suite"

echo "🔍 البحث عن أنظمة الزحف في السويت..."
find "$SUITE_DIR" -name "*spider*" -o -name "*crawl*" -o -name "*scraper*" | while read file; do
    if [[ -f "$file" ]]; then
        echo "✅ $(echo "$file" | sed "s|$SUITE_DIR/||")"
        # عرض نوع الملف
        if [[ "$file" == *.py ]]; then
            echo "   🐍 Python script"
            head -5 "$file" | grep -E "def |class |import" | head -2 | while read line; do
                echo "   💡 $line"
            done
        elif [[ "$file" == *.sh ]]; then
            echo "   🔧 Shell script"
        fi
    fi
done

echo
echo "🔍 فحص مجلد ingest بالتفصيل..."
if [[ -d "$SUITE_DIR/ingest" ]]; then
    find "$SUITE_DIR/ingest" -type f -name "*.py" | while read file; do
        echo "📄 $(basename "$file")"
        # التحقق إذا كان يحتوي على وظائف زحف
        if grep -q -E "crawl|spider|scrape|fetch" "$file"; then
            echo "   🕷️ Contains crawling functions"
        fi
    done
fi

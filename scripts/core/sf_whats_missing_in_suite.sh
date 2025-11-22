#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🔍 What's MISSING in Suite vs SmartFrind"
echo "==============================================="
echo

SMARTFRIND_DIR="/opt/smartfrind"
SUITE_DIR="/opt/smartfriend-suite"

echo "📊 مقارنة الميزات الناقصة في السويت:"
echo "----------------------------------------"

# 1) فحص أنظمة التعلم
echo "🧠 أنظمة التعلم الناقصة في السويت:"
find "$SMARTFRIND_DIR" -name "*learn*.py" | while read sf_file; do
    file_name=$(basename "$sf_file")
    suite_file="$SUITE_DIR/bots/$file_name"
    
    if [[ ! -f "$suite_file" ]]; then
        echo "❌ $file_name - غير موجود في السويت"
        echo "   📍 الموقع في smartfrind: $(dirname "$sf_file" | sed "s|$SMARTFRIND_DIR/||")"
        
        # عرض وصف الملف
        head -5 "$sf_file" | grep -E "def |class |\"\"\"" | head -2 | while read line; do
            echo "   💡 $line"
        done
    fi
done

# 2) فحص أنظمة الذاكرة المتقدمة
echo
echo "💾 أنظمة الذاكرة الناقصة في السويت:"
find "$SMARTFRIND_DIR" -name "*memory*.py" -path "*/app/smartfrind/*" | while read sf_file; do
    file_name=$(basename "$sf_file")
    suite_file="$SUITE_DIR/packages/memory/$file_name"
    
    if [[ ! -f "$suite_file" ]]; then
        echo "❌ $file_name - غير موجود في السويت"
        echo "   📍 الموقع: app/smartfrind/"
        
        # عرض حجم الملف
        lines=$(wc -l < "$sf_file")
        echo "   📏 الحجم: $lines سطر"
    fi
done

# 3) فحص البوابات وال APIs
echo
echo "🌐 البوابات وال APIs الناقصة في السويت:"
find "$SMARTFRIND_DIR" -name "*gateway*.py" -o -name "*api*.py" | grep -v "__pycache__" | while read sf_file; do
    file_name=$(basename "$sf_file")
    suite_file="$SUITE_DIR/packages/api/$file_name"
    
    if [[ ! -f "$suite_file" ]] && [[ ! -f "$SUITE_DIR/bots/$file_name" ]]; then
        echo "❌ $file_name - غير موجود في السويت"
        echo "   📍 الموقع: $(dirname "$sf_file" | sed "s|$SMARTFRIND_DIR/||")"
    fi
done

# 4) فحص الـ Spider
echo
echo "🕷️ أنظمة الزحف الناقصة في السويت:"
find "$SMARTFRIND_DIR" -name "*spider*.py" -o -name "*crawl*.py" | while read sf_file; do
    file_name=$(basename "$sf_file")
    suite_file="$SUITE_DIR/packages/ingest/$file_name"
    
    if [[ ! -f "$suite_file" ]] && [[ ! -f "$SUITE_DIR/bots/$file_name" ]]; then
        echo "❌ $file_name - غير موجود في السويت"
        echo "   📍 الموقع: $(dirname "$sf_file" | sed "s|$SMARTFRIND_DIR/||")"
    fi
done

echo
echo "🎯 التوصية: ندمج هذه الملفات الناقصة في السويت"

#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔗 دمج نظام المعرفة مع SmartFrind-Core..."

# البحث عن ملفات Core التي تحتاج التحديث
find /opt/smartfriend-suite -name "*.py" -type f | xargs grep -l "ai_memory\|knowledge" | grep -v "__pycache__" | while read file; do
    echo "📄 ملف يحتاج مراجعة: $file"
done

echo ""
echo "🎯 نقاط التكامل المقترحة:"
echo "1. استبدال استعلامات ai_memory المباشرة بـ /api/knowledge/search"
echo "2. استخدام /api/learn/random للمحتوى التعليمي" 
echo "3. استخدام /api/knowledge/categories لتصنيف المحتوى"
echo "4. استخدام /api/learn/interactive للتعلم التفاعلي"

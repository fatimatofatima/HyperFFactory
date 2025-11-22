#!/usr/bin/env bash
set -Eeuo pipefail

echo "🔧 إصلاح الـ Spider ليتوافق مع الهيكل الفعلي..."
cd /opt/smartfriend-suite

# إصلاح smart_spider.py لاستخدام الأعمدة الصحيحة
echo "🔄 تحديث smart_spider.py..."
sed -i 's/INSERT INTO ai_memory (content, source, content_type, created_at)/INSERT INTO ai_memory (user_input, ai_response, category, source, created_at)/g' bots/smart_spider.py

# تحديث استعلامات الإدراج
sed -i "s/'source_url'/'source'/g" bots/smart_spider.py
sed -i "s/'content_type'/'category'/g" bots/smart_spider.py

# إضافة استيراد sqlite3 إذا كان مفقوداً
if ! grep -q "import sqlite3" bots/smart_spider.py; then
    sed -i '1i import sqlite3' bots/smart_spider.py
fi

echo "✅ تم إصلاح الـ Spider"

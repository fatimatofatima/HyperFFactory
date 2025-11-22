#!/bin/bash
echo "=== فحص قاعدة البيانات ==="
DB_FILE="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
if [ -f "$DB_FILE" ]; then
    echo "✅ قاعدة البيانات موجودة: $DB_FILE"
    size=$(du -h "$DB_FILE" | cut -f1)
    echo "📊 الحجم: $size"
    
    # عدد الجداول
    tables=$(sqlite3 "$DB_FILE" ".tables" | wc -w)
    echo "📋 عدد الجداول: $tables"
    
    # أهم الجداول
    echo "🔍 أهم الجداول:"
    sqlite3 "$DB_FILE" ".tables" | tr ' ' '\n' | grep -E "(memory|knowledge|ai_|conversation)" | head -10
else
    echo "❌ قاعدة البيانات غير موجودة"
fi

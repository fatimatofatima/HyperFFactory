#!/bin/bash
echo "🗃️ مدير قواعد البيانات"

DB_DIR="/root/hyper-factory/data_lakehouse/db/sqlite"
COLD_STORAGE="/root/hyper-factory/data_lakehouse/db/cold_storage"

# إنشاء cold storage إذا لم يكن موجوداً
mkdir -p "$COLD_STORAGE"

echo "🔍 فحص قواعد البيانات..."
find "$DB_DIR" -name "*.db" -type f | while read db; do
    size=$(du -h "$db" | cut -f1)
    mtime=$(stat -c %y "$db" | cut -d' ' -f1)
    echo "📁 $db - $size - $mtime"
done | sort -rh | head -20

echo "💾 نقل الملفات القديمة إلى cold storage..."
find "$DB_DIR" -name "*.db" -type f -mtime +7 -exec mv {} "$COLD_STORAGE/" \; 2>/dev/null

echo "✅ تم إدارة قواعد البيانات"

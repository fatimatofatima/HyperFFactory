#!/bin/bash
DB="/root/hyper-factory/data/knowledge/knowledge.db"

echo "🔧 إصلاح كامل لقاعدة المعرفة..."

sqlite3 "$DB" << 'SQL'
-- إضافة الأعمدة المفقودة إذا لم تكن موجودة
ALTER TABLE project_merging ADD COLUMN IF NOT EXISTS sha256 TEXT;
ALTER TABLE project_merging ADD COLUMN IF NOT EXISTS size_bytes INTEGER;
ALTER TABLE project_merging ADD COLUMN IF NOT EXISTS db_path TEXT;

-- التحقق من الهيكل النهائي
.schema project_merging
SQL

echo "✅ تم الإصلاح"

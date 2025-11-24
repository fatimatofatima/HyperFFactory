#!/bin/bash
echo "🔧 إصلاح جدول المهام..."

# نسخ الجدول الحالي
sqlite3 data/factory/factory.db "
CREATE TABLE tasks_new AS SELECT * FROM tasks;
DROP TABLE tasks;
CREATE TABLE tasks AS SELECT * FROM tasks_new;
DROP TABLE tasks_new;
"

echo "✅ تم إصلاح جدول المهام"

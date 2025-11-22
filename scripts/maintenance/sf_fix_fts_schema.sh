#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🔧 Fixing FTS Schema Issues"
echo "==========================================="
echo

DB_MAIN="/var/lib/smartfrind/smart_memory.db"

# إصلاح مشكلة الـ FTS schema
echo "🔧 إصلاح جداول FTS..."
sqlite3 "$DB_MAIN" "
-- حذف جداول FTS القديمة إذا كانت تسبب مشاكل
DROP TABLE IF EXISTS ai_memory_fts;

-- إعادة إنشاء ai_memory_fts بالـ schema الصحيح
CREATE VIRTUAL TABLE ai_memory_fts USING fts5(
    question, 
    answer,
    category,
    tokenize = 'porter unicode61'
);

-- إعادة فهرسة البيانات من ai_memory
INSERT INTO ai_memory_fts (rowid, question, answer, category)
SELECT id, question, answer, category FROM ai_memory;

-- التحقق من الإصلاح
SELECT '✅ FTS tables rebuilt successfully';
"

echo "✅ تم إصلاح مشاكل الـ FTS schema"

#!/usr/bin/env bash
set -Eeuo pipefail

DB="/var/lib/smartfrind/smart_memory.db"
BACKUP="/var/lib/smartfrind/smart_memory_fts_fix_$(date +%Y%m%d_%H%M%S).db"

echo "📦 أخذ نسخة احتياطية من قاعدة البيانات في: $BACKUP"
cp "$DB" "$BACKUP"

echo "🛠 إعادة بناء جدول ai_memory_fts والتريجرز المرتبطة به..."

sqlite3 "$DB" <<'SQL'
PRAGMA foreign_keys=OFF;
BEGIN;

-- حذف التريجرز القديمة لو موجودة
DROP TRIGGER IF EXISTS ai_memory_ai;
DROP TRIGGER IF EXISTS ai_memory_au;
DROP TRIGGER IF EXISTS ai_memory_ad;

-- حذف جدول FTS القديم
DROP TABLE IF EXISTS ai_memory_fts;

-- إنشاء جدول FTS جديد مع أعمدة إضافية تدعم المسارات القديمة
CREATE VIRTUAL TABLE ai_memory_fts USING fts5(
    question,
    answer,
    category,
    user_input,
    ai_response,
    content='ai_memory',
    content_rowid='id'
);

-- إعادة ملء الـ FTS من ai_memory
INSERT INTO ai_memory_fts(rowid, question, answer, category, user_input, ai_response)
SELECT
    id AS rowid,
    COALESCE(question, user_input, '')           AS question,
    COALESCE(answer,  ai_response, '')           AS answer,
    COALESCE(category, 'general')                AS category,
    COALESCE(user_input, '')                     AS user_input,
    COALESCE(ai_response, '')                    AS ai_response
FROM ai_memory;

-- تريجر الإدخال
CREATE TRIGGER ai_memory_ai AFTER INSERT ON ai_memory BEGIN
    INSERT INTO ai_memory_fts(rowid, question, answer, category, user_input, ai_response)
    VALUES (
        new.id,
        COALESCE(new.question, new.user_input, ''),
        COALESCE(new.answer,  new.ai_response, ''),
        COALESCE(new.category, 'general'),
        COALESCE(new.user_input, ''),
        COALESCE(new.ai_response, '')
    );
END;

-- تريجر التحديث
CREATE TRIGGER ai_memory_au AFTER UPDATE ON ai_memory BEGIN
    UPDATE ai_memory_fts
    SET
        question   = COALESCE(new.question, new.user_input, ''),
        answer     = COALESCE(new.answer,  new.ai_response, ''),
        category   = COALESCE(new.category, 'general'),
        user_input = COALESCE(new.user_input, ''),
        ai_response= COALESCE(new.ai_response, '')
    WHERE rowid = new.id;
END;

-- تريجر الحذف
CREATE TRIGGER ai_memory_ad AFTER DELETE ON ai_memory BEGIN
    DELETE FROM ai_memory_fts WHERE rowid = old.id;
END;

COMMIT;
SQL

echo "✅ تم إصلاح ai_memory_fts وإعادة بناء التريجرز."

echo "📊 تحقق سريع:"
sqlite3 "$DB" "SELECT 'ai_memory' AS table_name, count(*) FROM ai_memory
               UNION ALL
               SELECT 'ai_memory_fts', count(*) FROM ai_memory_fts;"

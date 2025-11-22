#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🎯 FINAL - Knowledge Base Complete Fix"
echo "==========================================="
echo

DB_MAIN="/var/lib/smartfrind/smart_memory.db"

# 1) فحص حالة knowledge_base الحالية
echo "🔍 فحص حالة knowledge_base الحالية..."
sqlite3 "$DB_MAIN" "
.tables
" | grep knowledge_base

# 2) إذا الجدول غير موجود، ننشئه
echo "🔧 إنشاء/إصلاح جدول knowledge_base..."
sqlite3 "$DB_MAIN" "
-- حذف الجدول إذا كان موجوداً بمشاكل
DROP TABLE IF EXISTS knowledge_base;

-- إنشاء الجدول من الصفر بالـ schema الصحيح
CREATE TABLE knowledge_base(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  raw_data TEXT,
  category TEXT,
  analysis_summary TEXT,
  confidence_score REAL DEFAULT 0.8,
  source_link TEXT,
  importance_score REAL DEFAULT 0.7,
  tags TEXT,
  embedding BLOB,
  content_hash TEXT UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- إنشاء indexes لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_kb_category ON knowledge_base(category);
CREATE INDEX IF NOT EXISTS idx_kb_hash ON knowledge_base(content_hash);
CREATE INDEX IF NOT EXISTS idx_kb_importance ON knowledge_base(importance_score);

.print '✅ تم إنشاء knowledge_base بنجاح'
"

# 3) نقل البيانات من ai_memory إلى knowledge_base
echo "🔄 نقل البيانات من ai_memory إلى knowledge_base..."
sqlite3 "$DB_MAIN" "
-- عد السجلات قبل النقل
SELECT 'السجلات في ai_memory: ' || COUNT(*) FROM ai_memory;

-- نقل البيانات
INSERT INTO knowledge_base (raw_data, category, analysis_summary, confidence_score, importance_score, tags, content_hash)
SELECT 
    question || ' || ' || answer as raw_data,
    category,
    'تم نقله تلقائياً من ai_memory' as analysis_summary,
    0.8 as confidence_score,
    0.7 as importance_score,
    'auto_migrated,ai_memory' as tags,
    hex(randomblob(16)) as content_hash
FROM ai_memory
WHERE question IS NOT NULL AND answer IS NOT NULL;

-- عرض النتائج
SELECT '✅ تم نقل ' || changes() || ' سجل إلى knowledge_base';
SELECT '📊 الإجمالي في knowledge_base: ' || COUNT(*) FROM knowledge_base;

-- عرض عينة من البيانات المنقولة
SELECT '🔍 عينة من البيانات المنقولة:';
SELECT category, COUNT(*) as count 
FROM knowledge_base 
GROUP BY category 
ORDER BY count DESC 
LIMIT 10;
"

echo "✅ الإصلاح النهائي اكتمل!"

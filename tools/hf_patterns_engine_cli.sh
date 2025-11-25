#!/usr/bin/env bash
# HyperFFactory – Simple Patterns Engine (from hf_learning.db → hf_patterns.db)

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"

DB_LEARNING="$META_DIR/hf_learning.db"
DB_PATTERNS="$META_DIR/hf_patterns.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت: apt-get update && apt-get install -y sqlite3"
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Patterns Engine CLI"
echo " ROOT: $ROOT"
echo " TIME: $NOW"
echo "=================================================="
echo "⚙️  مصدر التعلم : $DB_LEARNING"
echo "📦 قاعدة الأنماط: $DB_PATTERNS"
echo "=================================================="
echo

if [ ! -f "$DB_LEARNING" ]; then
  echo "❌ ملف hf_learning.db غير موجود: $DB_LEARNING"
  exit 1
fi

mkdir -p "$META_DIR"

ensure_patterns_schema() {
  # لو القاعدة مش موجودة أصلاً → أنشئها مع الجدول مباشرة
  if [ ! -f "$DB_PATTERNS" ]; then
    echo "ℹ️ إنشاء قاعدة hf_patterns.db جديدة..."
    sqlite3 "$DB_PATTERNS" 'CREATE TABLE patterns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pattern_key   TEXT NOT NULL,
      source        TEXT NOT NULL,
      occurrences   INTEGER NOT NULL,
      first_rowid   INTEGER,
      last_rowid    INTEGER,
      score         REAL,
      tags          TEXT,
      UNIQUE(pattern_key, source)
    );'
    echo "✅ تم إنشاء جدول patterns بهيكل قياسي (جديد)."
    return
  fi

  # لو ملف DB موجود: نفحص وجود جدول patterns
  local has_table
  has_table=$(sqlite3 "$DB_PATTERNS" "SELECT name FROM sqlite_master WHERE type='table' AND name='patterns';" 2>/dev/null || echo "")

  if [ -z "$has_table" ]; then
    echo "ℹ️ قاعدة hf_patterns.db موجودة لكن بدون جدول patterns – سيتم إنشاؤه..."
    sqlite3 "$DB_PATTERNS" 'CREATE TABLE patterns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pattern_key   TEXT NOT NULL,
      source        TEXT NOT NULL,
      occurrences   INTEGER NOT NULL,
      first_rowid   INTEGER,
      last_rowid    INTEGER,
      score         REAL,
      tags          TEXT,
      UNIQUE(pattern_key, source)
    );'
    echo "✅ تم إنشاء جدول patterns جديد داخل hf_patterns.db."
    return
  fi

  # جدول patterns موجود: نتأكد من الأعمدة
  local cnt_expected
  cnt_expected=$(sqlite3 "$DB_PATTERNS" "SELECT COUNT(*) FROM pragma_table_info('patterns') WHERE name IN ('pattern_key','source','occurrences','first_rowid','last_rowid','score','tags');" 2>/dev/null || echo "0")

  if [ "$cnt_expected" -lt 7 ]; then
    echo "⚠️ تم العثور على جدول patterns لكن الـ schema قديمة أو مختلفة."
    echo "   سيتم أخذ نسخة احتياطية للـ DB وإعادة إنشاء الجدول بهيكل قياسي."

    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    local backup="${DB_PATTERNS}.bak.${ts}"

    cp "$DB_PATTERNS" "$backup"
    echo "💾 Backup: $backup"

    sqlite3 "$DB_PATTERNS" 'DROP TABLE IF EXISTS patterns;'
    sqlite3 "$DB_PATTERNS" 'CREATE TABLE patterns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pattern_key   TEXT NOT NULL,
      source        TEXT NOT NULL,
      occurrences   INTEGER NOT NULL,
      first_rowid   INTEGER,
      last_rowid    INTEGER,
      score         REAL,
      tags          TEXT,
      UNIQUE(pattern_key, source)
    );'
    echo "✅ تم إصلاح schema جدول patterns (مع الاحتفاظ بنسخة احتياطية)."
  else
    echo "✅ جدول patterns موجود و schema تبدو متوافقة."
  fi
}

# 1) ضمان الـ schema
ensure_patterns_schema
echo

# 2) التأكد من جدول learning وعمود pattern في hf_learning.db
HAS_LEARNING=$(sqlite3 "$DB_LEARNING" "SELECT name FROM sqlite_master WHERE type='table' AND name='learning';" 2>/dev/null || echo "")
if [ -z "$HAS_LEARNING" ]; then
  echo "⚠️ جدول learning غير موجود داخل hf_learning.db – لن يتم استخراج أنماط من هذا المصدر."
  exit 0
fi

HAS_PATTERN_COL=$(sqlite3 "$DB_LEARNING" "SELECT name FROM pragma_table_info('learning') WHERE name='pattern';" 2>/dev/null || echo "")
if [ -z "$HAS_PATTERN_COL" ]; then
  echo "⚠️ عمود pattern غير موجود في جدول learning – لن يتم استخراج أنماط."
  exit 0
fi

echo "🔍 استخراج الأنماط من hf_learning.db.learning (pattern، مع counts)..."
echo

# 3) إدخال/تحديث الأنماط داخل hf_patterns.db
sqlite3 "$DB_PATTERNS" <<SQL
ATTACH DATABASE '$DB_LEARNING' AS src;

INSERT INTO patterns (pattern_key, source, occurrences, first_rowid, last_rowid, score, tags)
SELECT
  pattern                AS pattern_key,
  'learning'             AS source,
  COUNT(*)               AS occurrences,
  MIN(rowid)             AS first_rowid,
  MAX(rowid)             AS last_rowid,
  COUNT(*) * 1.0         AS score,
  ''                     AS tags
FROM src.learning
WHERE pattern IS NOT NULL AND pattern <> ''
GROUP BY pattern
ON CONFLICT(pattern_key, source) DO UPDATE SET
  occurrences = excluded.occurrences,
  first_rowid = excluded.first_rowid,
  last_rowid  = excluded.last_rowid,
  score       = excluded.score;

DETACH DATABASE src;
SQL

echo "✅ تم تحديث جدول patterns من جدول learning."
echo

# 4) ملخص سريع
TOTAL_PATTERNS=$(sqlite3 "$DB_PATTERNS" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "?")
echo "📊 إجمالي الأنماط المسجلة: $TOTAL_PATTERNS"
echo

echo "🔝 أعلى 10 أنماط حسب occurrences:"
sqlite3 "$DB_PATTERNS" <<'SQL'
.headers off
.mode column
.width 40 10 10
SELECT
  pattern_key,
  source,
  occurrences
FROM patterns
ORDER BY occurrences DESC, pattern_key ASC
LIMIT 10;
SQL

echo
echo "=================================================="
echo " انتهاء تشغيل Patterns Engine CLI (READ hf_learning → WRITE hf_patterns)"
echo "=================================================="

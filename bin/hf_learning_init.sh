#!/usr/bin/env bash
# HyperFFactory - Initialize hf_learning.db (learning table only)
# - لا يحذف أي شيء
# - ينشئ جدول learning لو مش موجود
# - يسجل التقدّم في hf_changes.db لو hf_progress_log.sh موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"
LEARNING_DB="$DB_DIR/hf_learning.db"
PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

log_progress() {
  local msg="${1:-INIT}"
  if [[ -x "$PROGRESS_LOG" ]]; then
    "$PROGRESS_LOG" "hf_learning_init" "$msg" || true
  fi
}

mkdir -p "$DB_DIR"

echo "=================================================="
echo "🧠 HyperFFactory – Init hf_learning.db"
echo "📂 DB : $LEARNING_DB"
echo "=================================================="

# إنشاء الملف لو مش موجود
if [[ ! -f "$LEARNING_DB" ]]; then
  echo "📁 إنشاء ملف قاعدة البيانات hf_learning.db (جديد)"
  sqlite3 "$LEARNING_DB" 'PRAGMA journal_mode=WAL;' >/dev/null 2>&1 || true
else
  echo "ℹ️ ملف hf_learning.db موجود بالفعل (لن يتم حذفه)"
fi

# إنشاء جدول learning لو مش موجود
echo "🛠  التأكد من وجود جدول learning ..."
sqlite3 "$LEARNING_DB" '
CREATE TABLE IF NOT EXISTS learning (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  source     TEXT NOT NULL,
  pattern    TEXT NOT NULL,
  outcome    TEXT,
  confidence REAL,
  ts         TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_learning_source_ts ON learning(source, ts);
' >/dev/null

echo "✅ جدول learning جاهز في hf_learning.db"

log_progress "learning_table_ready"

echo "=================================================="
echo "✅ hf_learning.db جاهز للاستخدام (learning table)"
echo "=================================================="

#!/usr/bin/env bash
# HyperFFactory - Bootstrap hf_learning.db (create learning table if needed)
# - لا يحذف أي شيء، فقط ينشئ الجدول إن لم يكن موجودًا
# - يلتزم بسياسة الشجرة الموحّدة (كل شيء داخل /root/HyperFFactory)
# - يسجّل التقدّم في hf_changes.db لو hf_progress_log.sh موجود

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
DB_DIR="$ROOT_DIR/db/meta"
DB_FILE="$DB_DIR/hf_learning.db"
PROGRESS_LOG="$ROOT_DIR/bin/hf_progress_log.sh"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت، لن يتم إنشاء أي جداول"
  exit 1
fi

mkdir -p "$DB_DIR"

echo "=================================================="
echo "🧠 HyperFFactory – Bootstrap hf_learning.db"
echo "📂 DB : $DB_FILE"
echo "=================================================="

sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS learning (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  source     TEXT    NOT NULL,   -- اسم الـ actor أو النظام (hf_health_all, health_ffactory, coach, analyst, ...)
  pattern    TEXT    NOT NULL,   -- وصف النمط أو الخبرة أو الحدث المتعلّم
  outcome    TEXT,               -- نتيجة النمط (نجاح/فشل/تحسين/... أو نص حر)
  confidence REAL,               -- درجة الثقة (0.0 → 1.0)
  ts         TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE INDEX IF NOT EXISTS idx_learning_source_ts
  ON learning (source, ts);

CREATE INDEX IF NOT EXISTS idx_learning_pattern_ts
  ON learning (pattern, ts);
SQL

echo "✅ تم التأكد من وجود جدول learning في hf_learning.db"

# تسجيل التقدّم لو سكربت اللوج موجود
if [ -x "$PROGRESS_LOG" ]; then
  "$PROGRESS_LOG" "hf_learning_bootstrap" "learning_table_ensure" "INFO" "hf_learning.db: learning table ensured"
  echo "✅ Progress logged: hf_learning_bootstrap [INFO]"
else
  echo "ℹ️ ملاحظة: hf_progress_log.sh غير موجود/ليس قابل للتنفيذ، لم يتم تسجيل التقدّم في hf_changes.db"
fi

echo "=================================================="
echo "✅ Bootstrap مكتمل لـ hf_learning.db"
echo "=================================================="

#!/usr/bin/env bash
# HyperFFactory - Errors DB Init
# إنشاء/تحديث قاعدة بيانات الأخطاء: db/meta/hf_errors.db

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_errors.db"

mkdir -p "$META_DIR"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

echo "=================================================="
echo "🧱 HyperFFactory – Errors DB Init"
echo "📍 Root : $ROOT_DIR"
echo "📄 DB   : $DB"
echo "=================================================="

sqlite3 "$DB" <<'SQL'
PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS errors (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  actor         TEXT NOT NULL,      -- من اكتشف/سجّل الخطأ (hf_health_all / hyper_guard / ...)
  error_type    TEXT NOT NULL,      -- نوع الخطأ (service_status / db_check / ...)
  error_message TEXT NOT NULL,      -- وصف الخطأ
  severity      TEXT NOT NULL       -- LOW / MEDIUM / HIGH / CRITICAL
                CHECK(severity IN ('LOW','MEDIUM','HIGH','CRITICAL')),
  context       TEXT,               -- أوامر/مسارات/مزيد من التفاصيل
  ts            TEXT NOT NULL       -- توقيت التسجيل
);

CREATE INDEX IF NOT EXISTS idx_errors_severity ON errors(severity);
CREATE INDEX IF NOT EXISTS idx_errors_actor    ON errors(actor);
CREATE INDEX IF NOT EXISTS idx_errors_ts       ON errors(ts);
SQL

echo "✅ تم إنشاء/تحديث قاعدة بيانات الأخطاء: $DB"

PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_errors_init" "DONE" "db=$DB"
fi

echo "=================================================="
echo "✅ hf_errors_init.sh انتهى بنجاح."
echo "=================================================="

#!/usr/bin/env bash
# HyperFFactory - Quality DB Init
# إنشاء/تحديث قاعدة بيانات الجودة: db/meta/hf_quality.db
# يحافظ على البيانات القديمة ويضيف عمود scope عند الحاجة.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/bin}"
META_DIR="$ROOT_DIR/db/meta"
DB="$META_DIR/hf_quality.db"

mkdir -p "$META_DIR"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت sqlite3 ثم أعد المحاولة." >&2
  exit 1
fi

echo "=================================================="
echo "🧱 HyperFFactory – Quality DB Init"
echo "📍 Root : $ROOT_DIR"
echo "📄 DB   : $DB"
echo "=================================================="

# 1) إنشاء الجدول الأساسي لو غير موجود (بـ scope)
sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS quality_checks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  actor      TEXT NOT NULL,   -- من ينفّذ الفحص (hf_health_all / sf-core / ffactory_health / ...)
  check_name TEXT NOT NULL,   -- اسم الفحص (smartfriend_services, ffactory_docker, backup_policy, ...)
  scope      TEXT,            -- نطاق الفحص (hyper/smartfriend/ffactory/...)
  result     TEXT NOT NULL,   -- PASS / FAIL / WARN / SKIP
  score      INTEGER NOT NULL DEFAULT 0, -- 0–100
  details    TEXT,            -- وصف حر
  tags       TEXT,            -- نص حر (csv/json بسيط)
  ts         TEXT NOT NULL    -- وقت التنفيذ
);

CREATE INDEX IF NOT EXISTS idx_quality_ts         ON quality_checks(ts);
CREATE INDEX IF NOT EXISTS idx_quality_actor      ON quality_checks(actor);
CREATE INDEX IF NOT EXISTS idx_quality_check_name ON quality_checks(check_name);
CREATE INDEX IF NOT EXISTS idx_quality_result     ON quality_checks(result);
SQL

# 2) التأكد من وجود العمود scope في الجداول القديمة
if ! sqlite3 "$DB" "PRAGMA table_info(quality_checks);" | awk -F'|' '$2=="scope"{f=1} END{exit (f?0:1)}'; then
  echo "ℹ️ إضافة عمود scope إلى quality_checks (بدون لمس البيانات القديمة)..."
  sqlite3 "$DB" "ALTER TABLE quality_checks ADD COLUMN scope TEXT;"
fi

# 3) تسجيل التقدّم في hf_changes/hf_progress إن أمكن
PROG_LOG="$ROOT_DIR/bin/hf_progress_log.sh"
if [[ -x "$PROG_LOG" ]]; then
  "$PROG_LOG" "hf_quality_init" "DONE" "quality_checks schema ensured (scope column present)"
fi

echo "✅ تم إنشاء/تحديث قاعدة بيانات الجودة: $DB"
echo "=================================================="

#!/usr/bin/env bash
# HyperFFactory – Errors & Incidents Schema Upgrade

set -euo pipefail

ROOT="${1:-/root/HyperFFactory}"
META_DIR="$ROOT/db/meta"
DB_ERRORS="$META_DIR/hf_errors.db"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "❌ sqlite3 غير مثبت. ثبّت: apt-get update && apt-get install -y sqlite3"
  exit 1
fi

NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"

echo "=================================================="
echo " HyperFFactory – Errors & Incidents Schema Upgrade"
echo " ROOT : $ROOT"
echo " DB   : $DB_ERRORS"
echo " TIME : $NOW"
echo "=================================================="
echo

mkdir -p "$META_DIR"

# إنشاء hf_errors.db لو غير موجود
if [ ! -f "$DB_ERRORS" ]; then
  echo "⚠️ إنشاء قاعدة hf_errors.db جديدة..."
  sqlite3 "$DB_ERRORS" 'PRAGMA journal_mode=WAL;' >/dev/null 2>&1 || true
fi

echo "🧩 التأكد من وجود جدول incidents بالسكيمة القياسية..."

sqlite3 "$DB_ERRORS" <<'SQL'
CREATE TABLE IF NOT EXISTS incidents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor TEXT NOT NULL,
  error_type TEXT NOT NULL,
  error_message TEXT NOT NULL,
  severity TEXT NOT NULL,                -- LOW / MEDIUM / HIGH / CRITICAL
  ts TEXT NOT NULL,                      -- timestamp للحدث (UTC+3 حسب النظام)
  context TEXT,                          -- نص حر للسياق (path, report, extra info)
  source_script TEXT,                    -- اسم السكربت/المصدر
  exit_code INTEGER,                     -- كود الخروج إن وجد
  ref_change_id INTEGER,                 -- ربط اختياري مع hf_changes (change id)
  ref_report_path TEXT,                 -- مسار تقرير/لوج
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_incidents_ts
  ON incidents (ts);

CREATE INDEX IF NOT EXISTS idx_incidents_severity
  ON incidents (severity);

CREATE INDEX IF NOT EXISTS idx_incidents_actor_ts
  ON incidents (actor, ts);
SQL

echo
echo "✅ سكيمة incidents جاهزة داخل hf_errors.db"
echo "=================================================="
echo " انتهاء ترقية Errors & Incidents Schema"
echo "=================================================="

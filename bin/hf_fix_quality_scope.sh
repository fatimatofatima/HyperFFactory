#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

mkdir -p "$ROOT/db" "$ROOT/db/migrations" "$ROOT/reports"

DB="$ROOT/db/quality.db"
MIG_DIR="$ROOT/db/migrations"
REPORT_DIR="$ROOT/reports"

TS="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="$REPORT_DIR/hf_fix_quality_scope_${TS}.log"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=================================================="
log "🔧 HF FIX QUALITY SCOPE COLUMN"
log "ROOT : $ROOT"
log "DB   : $DB"
log "LOG  : $LOG_FILE"
log "=================================================="

log "🔍 خطوة 1: تهيئة قاعدة البيانات إن لزم الأمر"

if [[ ! -f "$DB" ]]; then
  log "⚠️ قاعدة البيانات غير موجودة – سيتم إنشاؤها الآن مع جدول quality_checks."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS quality_checks (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  actor     TEXT    NOT NULL,
  check_name TEXT   NOT NULL,
  scope     TEXT    NOT NULL DEFAULT 'GLOBAL',
  result    TEXT    NOT NULL,
  score     INTEGER,
  details   TEXT,
  ts        TEXT    NOT NULL
);
SQL
  log "✅ تم إنشاء قاعدة البيانات والجدول quality_checks بالعمود scope."
  log "✅ الإصلاح مكتمل."
  exit 0
fi

log "ℹ️ قاعدة البيانات موجودة بالفعل – سيتم فحص الجداول والحقول."

log "🔍 خطوة 2: التأكد من وجود جدول quality_checks"
TABLE_EXISTS="$(sqlite3 "$DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='quality_checks';" || true)"

if [[ -z "$TABLE_EXISTS" ]]; then
  log "⚠️ جدول quality_checks غير موجود – سيتم إنشاؤه الآن."
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS quality_checks (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  actor     TEXT    NOT NULL,
  check_name TEXT   NOT NULL,
  scope     TEXT    NOT NULL DEFAULT 'GLOBAL',
  result    TEXT    NOT NULL,
  score     INTEGER,
  details   TEXT,
  ts        TEXT    NOT NULL
);
SQL
  log "✅ تم إنشاء جدول quality_checks من الصفر بالعمود scope."
  log "✅ الإصلاح مكتمل."
  exit 0
fi

log "ℹ️ جدول quality_checks موجود – سيتم فحص الأعمدة."

log "🔍 خطوة 3: التأكد من وجود العمود scope"

if sqlite3 "$DB" "PRAGMA table_info(quality_checks);" | \
   awk -F'|' '
     $2=="scope"{found=1}
     END{
       if (found) exit 0;
       else exit 1;
     }
   '
then
  log "ℹ️ العمود scope موجود بالفعل – لا حاجة لأي تعديل."
else
  log "⚠️ العمود scope غير موجود – سيتم إضافته الآن."
  sqlite3 "$DB" "ALTER TABLE quality_checks ADD COLUMN scope TEXT NOT NULL DEFAULT 'GLOBAL';"
  log "✅ تم إضافة العمود scope بنجاح."
fi

log "✅ الإصلاح مكتمل."

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

DB="/opt/smartfriend-suite/var/db/memory.db"
ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/MEMORY_SCHEMA_${TS}"

log "===== إصلاح سكيمة جدول sessions في memory.db ====="
log "DB           = ${DB}"
log "ARCHIVE_DIR  = ${ARCHIVE_DIR}"
echo

if [ ! -f "$DB" ]; then
  log "❌ قاعدة البيانات غير موجودة: $DB"
  exit 1
fi

# 1) Backup قبل أي تعديل
mkdir -p "$ARCHIVE_DIR"
cp -a "$DB" "${ARCHIVE_DIR}/memory.db"
log "✅ تم أخذ نسخة احتياطية من memory.db في: ${ARCHIVE_DIR}/memory.db"

# 2) عرض السكيمة الحالية لجدول sessions
log "[1] سكيمة sessions قبل التعديل:"
sqlite3 "$DB" "PRAGMA table_info(sessions);" | sed 's/^/    /'
echo

# 3) التحقق من وجود العمود session_id
log "[2] فحص وجود العمود session_id ..."
HAS_COL=$(sqlite3 "$DB" "PRAGMA table_info(sessions);" | awk -F'|' '{print $2}' | grep -xc 'session_id' || true)

if [ "$HAS_COL" -eq 0 ]; then
  log "⚠ لا يوجد عمود session_id في sessions -> سيتم إضافته"
  sqlite3 "$DB" "ALTER TABLE sessions ADD COLUMN session_id TEXT;" || {
    log "❌ فشل ALTER TABLE لإضافة session_id"
    exit 1
  }

  # لو الجدول فيه عمود id ننسخ قيمه لعمود session_id
  HAS_ID=$(sqlite3 "$DB" "PRAGMA table_info(sessions);" | awk -F'|' '{print $2}' | grep -xc 'id' || true)
  if [ "$HAS_ID" -gt 0 ]; then
    log "[3] نسخ القيم من id إلى session_id (إن وجدت صفوف)..."
    sqlite3 "$DB" "UPDATE sessions SET session_id = id WHERE session_id IS NULL;" || true
  else
    log "[3] لا يوجد عمود id في sessions، سيتم ترك session_id فارغ للصفوف الحالية (لو موجودة)."
  fi

  # إنشاء فهرس اختياري
  log "[4] إنشاء فهرس على session_id (إن لم يكن موجودًا)..."
  sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);" || true

  log "✅ تم إضافة العمود session_id (مع الفهرس إن أمكن)."
else
  log "✅ العمود session_id موجود بالفعل – لا حاجة للتعديل."
fi

echo
log "[5] سكيمة sessions بعد التعديل:"
sqlite3 "$DB" "PRAGMA table_info(sessions);" | sed 's/^/    /'

log "===== DONE: إصلاح سكيمة sessions في memory.db ====="

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

DB="/opt/smartfriend-suite/var/db/memory.db"
ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/MESSAGE_SCHEMA_${TS}"

log "===== إصلاح سكيمة جدول messages في memory.db ====="
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

# 2) عرض السكيمة الحالية لجدول messages
log "[1] سكيمة messages قبل التعديل:"
sqlite3 "$DB" "PRAGMA table_info(messages);" | sed 's/^/    /'
echo

# 3) التحقق من وجود العمود message_id
log "[2] فحص وجود العمود message_id ..."
HAS_COL=$(sqlite3 "$DB" "PRAGMA table_info(messages);" | awk -F'|' '{print $2}' | grep -xc 'message_id' || true)

if [ "$HAS_COL" -eq 0 ]; then
  log "⚠ لا يوجد عمود message_id في messages -> سيتم إضافته"
  sqlite3 "$DB" "ALTER TABLE messages ADD COLUMN message_id TEXT;" || {
    log "❌ فشل ALTER TABLE لإضافة message_id"
    exit 1
  }

  # لو الجدول فيه عمود id ننسخ قيمه لعمود message_id
  HAS_ID=$(sqlite3 "$DB" "PRAGMA table_info(messages);" | awk -F'|' '{print $2}' | grep -xc 'id' || true)
  if [ "$HAS_ID" -gt 0 ]; then
    log "[3] نسخ القيم من id إلى message_id (إن وجدت صفوف)..."
    sqlite3 "$DB" "UPDATE messages SET message_id = id WHERE message_id IS NULL;" || true
  else
    log "[3] لا يوجد عمود id في messages، سيتم ترك message_id فارغ للصفوف الحالية (لو موجودة)."
  fi

  # إنشاء فهرس اختياري
  log "[4] إنشاء فهرس على message_id (إن لم يكن موجودًا)..."
  sqlite3 "$DB" "CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id);" || true

  log "✅ تم إضافة العمود message_id (مع الفهرس إن أمكن)."
else
  log "✅ العمود message_id موجود بالفعل – لا حاجة للتعديل."
fi

echo
log "[5] سكيمة messages بعد التعديل:"
sqlite3 "$DB" "PRAGMA table_info(messages);" | sed 's/^/    /'

log "===== DONE: إصلاح سكيمة messages في memory.db ====="

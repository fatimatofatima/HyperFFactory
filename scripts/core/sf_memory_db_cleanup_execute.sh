#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

DB_DIR="/opt/smartfriend-suite/var/db"
ACTIVE_DB="${DB_DIR}/active_memory.db"
ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/MEMORY_DBS_${TS}"

log "تنفيذ تنظيف قواعد الذاكرة (نقل القديم إلى الأرشيف)"
log "DB_DIR = ${DB_DIR}"
log "ACTIVE_DB = ${ACTIVE_DB}"
log "ARCHIVE_DIR = ${ARCHIVE_DIR}"
echo

if [ ! -d "$DB_DIR" ]; then
  log "ERROR: مجلد قواعد البيانات غير موجود: $DB_DIR"
  exit 1
fi

if [ ! -f "$ACTIVE_DB" ]; then
  log "ERROR: active_memory.db غير موجود – لن أنفّذ أي نقل حفاظًا على الأمان."
  exit 1
fi

if [ ! -s "$ACTIVE_DB" ]; then
  log "ERROR: active_memory.db حجمها صفر أو غير صحيحة – أوقف التنفيذ فورًا."
  exit 1
fi

mkdir -p "$ARCHIVE_DIR"
log "✅ تم إنشاء مجلد الأرشيف: $ARCHIVE_DIR"

log "نقل قواعد الذاكرة القديمة إلى الأرشيف (مع الإبقاء على active_memory.db في مكانها)..."
find "$DB_DIR" -maxdepth 1 -type f \( \
  -name 'memory.db' -o \
  -name 'memory.db.*' -o \
  -name 'smart_core_memory.db' -o \
  -name 'smart_core_memory.db.*' -o \
  -name 'unified_memory.db' -o \
  -name 'unified_memory.db.*' \
  \) ! -name 'active_memory.db' | while read -r f; do
    log "Moving: $f -> $ARCHIVE_DIR/"
    mv "$f" "$ARCHIVE_DIR/" || log "WARN: فشل نقل $f"
done

echo
log "محتوى مجلد قواعد البيانات بعد التنظيف:"
ls -la "$DB_DIR" || true

echo
log "محتوى الأرشيف الجديد:"
ls -la "$ARCHIVE_DIR" || true

log "انتهى نقل قواعد الذاكرة القديمة – لا يوجد حذف نهائي حتى الآن، فقط نقل للأرشيف."

#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

MAIN_DB="/opt/smartfriend-suite/var/db/memory.db"
OLD_ROOT="/opt/COMPLETE_CODE_BACKUP"

# أخذ أحدث مجموعة MEMORY_DBS_* (التي نقلنا إليها old memory.db)
LATEST_SET="$(ls -1d "${OLD_ROOT}"/MEMORY_DBS_* 2>/dev/null | sort | tail -n1 || true)"
LATEST_OLD_DB=""
if [ -n "$LATEST_SET" ] && [ -f "${LATEST_SET}/memory.db" ]; then
  LATEST_OLD_DB="${LATEST_SET}/memory.db"
fi

log "فحص مخطط جدول sessions في قواعد الذاكرة"
log "MAIN_DB = ${MAIN_DB}"
if [ -n "${LATEST_OLD_DB}" ]; then
  log "OLD_DB  = ${LATEST_OLD_DB}"
else
  log "OLD_DB  = لا يوجد memory.db مؤرشف (أو لم يتم إيجاده تلقائيًا)"
fi
echo

echo "=== schema جدول sessions في memory.db الحالي ==="
if [ -f "${MAIN_DB}" ]; then
  echo "--- .schema sessions ---"
  sqlite3 "${MAIN_DB}" ".schema sessions" || echo "⚠ لا يمكن عرض .schema sessions في memory.db"
  echo
  echo "--- PRAGMA table_info('sessions') ---"
  sqlite3 "${MAIN_DB}" "PRAGMA table_info('sessions');" || echo "⚠ لا يمكن عرض table_info(sessions) في memory.db"
else
  echo "❌ ملف memory.db غير موجود في المسار المتوقع!"
fi

if [ -n "${LATEST_OLD_DB}" ]; then
  echo
  echo "=== schema جدول sessions في memory.db القديم من الأرشيف ==="
  echo "--- .schema sessions (old) ---"
  sqlite3 "${LATEST_OLD_DB}" ".schema sessions" || echo "⚠ لا يمكن عرض .schema sessions في old memory.db"
  echo
  echo "--- PRAGMA table_info('sessions') (old) ---"
  sqlite3 "${LATEST_OLD_DB}" "PRAGMA table_info('sessions');" || echo "⚠ لا يمكن عرض table_info(sessions) في old memory.db"
fi

echo
log "انتهى فحص مخطط sessions – لا يوجد أي تعديل على القواعد."

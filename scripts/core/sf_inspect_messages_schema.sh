#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

MAIN_DB="/opt/smartfriend-suite/var/db/memory.db"
OLD_ROOT="/opt/COMPLETE_CODE_BACKUP"

# أحدث MEMORY_DBS_* (لو موجودة) للمقارنة
LATEST_SET="$(ls -1d "${OLD_ROOT}"/MEMORY_DBS_* 2>/dev/null | sort | tail -n1 || true)"
LATEST_OLD_DB=""
if [ -n "$LATEST_SET" ] && [ -f "${LATEST_SET}/memory.db" ]; then
  LATEST_OLD_DB="${LATEST_SET}/memory.db"
fi

log "فحص مخطط جدول messages في قواعد الذاكرة"
log "MAIN_DB = ${MAIN_DB}"
if [ -n "${LATEST_OLD_DB}" ]; then
  log "OLD_DB  = ${LATEST_OLD_DB}"
else
  log "OLD_DB  = لا يوجد memory.db مؤرشف (أو لم يتم إيجاده تلقائيًا)"
fi
echo

echo "=== schema جدول messages في memory.db الحالي ==="
echo "--- .schema messages ---"
sqlite3 "$MAIN_DB" ".schema messages" || echo "❌ لا يمكن قراءة schema messages من MAIN_DB"
echo
echo "--- PRAGMA table_info('messages') ---"
sqlite3 "$MAIN_DB" "PRAGMA table_info(messages);" || echo "❌ فشل PRAGMA table_info(messages) في MAIN_DB"

if [ -n "${LATEST_OLD_DB}" ]; then
  echo
  echo "=== schema جدول messages في memory.db القديم من الأرشيف ==="
  echo "--- .schema messages (old) ---"
  sqlite3 "$LATEST_OLD_DB" ".schema messages" || echo "❌ لا يمكن قراءة schema messages من OLD_DB"
  echo
  echo "--- PRAGMA table_info('messages') (old) ---"
  sqlite3 "$LATEST_OLD_DB" "PRAGMA table_info(messages);" || echo "❌ فشل PRAGMA table_info(messages) في OLD_DB"
fi

log "انتهى فحص مخطط messages – لا يوجد أي تعديل على القواعد."

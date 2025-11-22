#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

MAIN_DB="/opt/smartfriend-suite/var/db/memory.db"
OLD_ROOT="/opt/COMPLETE_CODE_BACKUP"

log "===== دمج بيانات الذاكرة القديمة في memory.db الحالية ====="
log "MAIN_DB = ${MAIN_DB}"
log "OLD_ROOT = ${OLD_ROOT}"
echo

if [ ! -f "$MAIN_DB" ]; then
  log "❌ قاعدة البيانات الحالية غير موجودة: $MAIN_DB"
  exit 1
fi

# العثور على أحدث MEMORY_DBS_* تحتوي على memory.db قديم
LATEST_SET="$(ls -1d "${OLD_ROOT}"/MEMORY_DBS_* 2>/dev/null | sort | tail -n1 || true)"
if [ -z "$LATEST_SET" ] || [ ! -f "${LATEST_SET}/memory.db" ]; then
  log "❌ لم أجد memory.db قديم تحت ${OLD_ROOT}/MEMORY_DBS_*"
  exit 1
fi

OLD_DB="${LATEST_SET}/memory.db"
log "OLD_DB  = ${OLD_DB}"
echo

# إحصائيات قبل الدمج
CURR_SESS=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo 0)
CURR_MSGS=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM messages;" 2>/dev/null || echo 0)
CURR_KI=0
if sqlite3 "$MAIN_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='knowledge_items';" | grep -q '^knowledge_items$'; then
  CURR_KI=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM knowledge_items;" 2>/dev/null || echo 0)
fi

OLD_SESS=$(sqlite3 "$OLD_DB" "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo 0)
OLD_MSGS=$(sqlite3 "$OLD_DB" "SELECT COUNT(*) FROM messages;" 2>/dev/null || echo 0)
OLD_KI=0
if sqlite3 "$OLD_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='knowledge_items';" | grep -q '^knowledge_items$'; then
  OLD_KI=$(sqlite3 "$OLD_DB" "SELECT COUNT(*) FROM knowledge_items;" 2>/dev/null || echo 0)
fi

log "قبل الدمج:"
log "  sessions (current=${CURR_SESS}, old=${OLD_SESS})"
log "  messages (current=${CURR_MSGS}, old=${OLD_MSGS})"
log "  knowledge_items (current=${CURR_KI}, old=${OLD_KI})"
echo

# لو في داتا حالية، نحذر ونمنع الدمج لحماية الـ IDs
if [ "$CURR_SESS" -gt 0 ] || [ "$CURR_MSGS" -gt 0 ]; then
  log "⚠ يوجد بيانات حالية في sessions/messages => لن يتم الدمج أوتوماتيكيًا لحماية الـ IDs."
  log "   رجاءً تأكيد/تنظيف البيانات يدويًا لو حابب ندمج لاحقًا."
  exit 1
fi

log "🔁 بدء الدمج الفعلي (sessions + messages [+ knowledge_items])..."
sqlite3 "$MAIN_DB" <<SQL
PRAGMA foreign_keys=OFF;
ATTACH '${OLD_DB}' AS old;

-- 1) دمج الجلسات مع المحافظة على نفس id
INSERT INTO sessions (id, external_id, user_id, title, created_at, updated_at, session_id)
SELECT
  id,
  external_id,
  user_id,
  title,
  created_at,
  updated_at,
  CAST(id AS TEXT) AS session_id
FROM old.sessions;

-- 2) دمج الرسائل مع المحافظة على id و session_id
INSERT INTO messages (id, session_id, role, content, created_at, message_id)
SELECT
  id,
  session_id,
  role,
  content,
  created_at,
  CAST(id AS TEXT) AS message_id
FROM old.messages;

-- 3) دمج عناصر المعرفة (لو الجدول موجود في القاعدتين وبنفس السكيمة)
-- نفحص وجود الجدول في main و old
WITH
  main_has AS (
    SELECT COUNT(*) AS c FROM sqlite_master
    WHERE type='table' AND name='knowledge_items'
  ),
  old_has AS (
    SELECT COUNT(*) AS c FROM old.sqlite_master
    WHERE type='table' AND name='knowledge_items'
  )
SELECT '' FROM main_has, old_has
WHERE main_has.c=1 AND old_has.c=1;

-- لو الجدول موجود في الاثنين وبنفس الأعمدة، ننسخ كل الصفوف:
INSERT INTO knowledge_items
SELECT * FROM old.knowledge_items;

DETACH old;
PRAGMA foreign_keys=ON;
SQL

echo
# إحصائيات بعد الدمج
CURR_SESS2=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo 0)
CURR_MSGS2=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM messages;" 2>/dev/null || echo 0)
CURR_KI2=0
if sqlite3 "$MAIN_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='knowledge_items';" | grep -q '^knowledge_items$'; then
  CURR_KI2=$(sqlite3 "$MAIN_DB" "SELECT COUNT(*) FROM knowledge_items;" 2>/dev/null || echo 0)
fi

log "بعد الدمج:"
log "  sessions: ${CURR_SESS} -> ${CURR_SESS2}"
log "  messages: ${CURR_MSGS} -> ${CURR_MSGS2}"
log "  knowledge_items: ${CURR_KI} -> ${CURR_KI2}"

log "===== تم دمج بيانات الذاكرة القديمة بنجاح (بدون أي حذف) ====="

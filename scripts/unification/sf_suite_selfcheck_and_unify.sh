#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

SUITE_DIR="/opt/smartfriend-suite"
FF_DIR="/opt/ffactory"
DB_DIR="${SUITE_DIR}/var/db"
MEM_DB="${DB_DIR}/memory.db"
ACTIVE_DB="${DB_DIR}/active_memory.db"
UNIFIED_DB="${DB_DIR}/smartfriend_unified.db"
ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/SUITE_SELFCHK_${TS}"

log "===== SmartFriend Suite – Self Check & Unify (no symlink) ====="
log "SUITE_DIR   = ${SUITE_DIR}"
log "DB_DIR      = ${DB_DIR}"
log "ARCHIVE_DIR = ${ARCHIVE_DIR}"
echo

mkdir -p "${ARCHIVE_DIR}"

########################################
# 1) فحص ملفات قواعد البيانات
########################################
log "[1] فحص قواعد البيانات داخل السويت..."

if [ -d "${DB_DIR}" ]; then
  echo ">> محتوى ${DB_DIR}:"
  ls -la "${DB_DIR}"
  echo
else
  log "❌ مجلد قواعد البيانات غير موجود: ${DB_DIR}"
  exit 1
fi

if [ -f "${UNIFIED_DB}" ]; then
  size_unified=$(du -h "${UNIFIED_DB}" | cut -f1)
  log "ℹ smartfriend_unified.db موجودة (حجمها ${size_unified}) – لن يتم لمسها."
else
  log "⚠ smartfriend_unified.db غير موجودة في ${DB_DIR} – تأكد يدويًا إن كان هذا متعمدًا."
fi

if [ -f "${ACTIVE_DB}" ]; then
  size_active=$(du -h "${ACTIVE_DB}" | cut -f1)
  log "ℹ active_memory.db موجودة (حجمها ${size_active})."
else
  log "⚠ active_memory.db غير موجودة – سيتم الاعتماد فقط على memory.db إن وُجدت."
fi

if [ -f "${MEM_DB}" ]; then
  size_mem=$(du -h "${MEM_DB}" | cut -f1)
  log "ℹ memory.db موجودة (حجمها ${size_mem})."
else
  if [ -f "${ACTIVE_DB}" ]; then
    log "ℹ memory.db غير موجودة – سيتم إنشاؤها من active_memory.db..."
    cp -a "${ACTIVE_DB}" "${MEM_DB}"
    log "✅ تم إنشاء memory.db من active_memory.db."
  else
    log "❌ لا يوجد لا memory.db ولا active_memory.db – لا يمكن متابعة فحص الذاكرة."
    exit 1
  fi
fi

echo

########################################
# 2) Backup قبل أي تعديل على memory.db
########################################
log "[2] أخذ نسخة احتياطية من memory.db قبل أي تعديل سكيمة..."
cp -a "${MEM_DB}" "${ARCHIVE_DIR}/memory_before_fix.db"
log "✅ backup: ${ARCHIVE_DIR}/memory_before_fix.db"
echo

########################################
# Helper: التحقق إن جدول موجود
########################################
table_exists() {
  local db="$1"
  local tbl="$2"
  sqlite3 "${db}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${tbl}';" 2>/dev/null | grep -qx "${tbl}"
}

########################################
# 3) إصلاح سكيمة sessions (إضافة session_id إن لزم)
########################################
log "[3] فحص/إصلاح سكيمة جدول sessions في memory.db..."

if table_exists "${MEM_DB}" "sessions"; then
  log "ℹ جدول sessions موجود – فحص الأعمدة..."
  schema_sessions_before="$(sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');")"
  echo "PRAGMA table_info('sessions') قبل التعديل:"
  echo "${schema_sessions_before}"
  echo

  if sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');" | awk -F'|' '{print $2}' | grep -qx "session_id"; then
    log "ℹ العمود session_id موجود بالفعل في sessions – لا حاجة لإضافته."
  else
    log "⚠ session_id غير موجود – سيتم إضافته ونسخ id إليه..."
    sqlite3 "${MEM_DB}" <<'SQL'
ALTER TABLE sessions ADD COLUMN session_id TEXT;
UPDATE sessions SET session_id = id WHERE session_id IS NULL OR session_id = '';
CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
SQL
    log "✅ تم إضافة session_id إلى sessions وتعبئته من id (مع index إن أمكن)."
  fi

  echo
  log "PRAGMA table_info('sessions') بعد التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');"
  echo
else
  log "⚠ جدول sessions غير موجود في memory.db – سيتم تجاوزه."
fi

########################################
# 4) إصلاح سكيمة messages (إضافة message_id إن لزم)
########################################
log "[4] فحص/إصلاح سكيمة جدول messages في memory.db..."

if table_exists "${MEM_DB}" "messages"; then
  log "ℹ جدول messages موجود – فحص الأعمدة..."
  schema_messages_before="$(sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');")"
  echo "PRAGMA table_info('messages') قبل التعديل:"
  echo "${schema_messages_before}"
  echo

  if sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');" | awk -F'|' '{print $2}' | grep -qx "message_id"; then
    log "ℹ العمود message_id موجود بالفعل في messages – لا حاجة لإضافته."
  else
    log "⚠ message_id غير موجود – سيتم إضافته ونسخ id إليه..."
    sqlite3 "${MEM_DB}" <<'SQL'
ALTER TABLE messages ADD COLUMN message_id TEXT;
UPDATE messages SET message_id = id WHERE message_id IS NULL OR message_id = '';
CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id);
SQL
    log "✅ تم إضافة message_id إلى messages وتعبئته من id (مع index إن أمكن)."
  fi

  echo
  log "PRAGMA table_info('messages') بعد التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');"
  echo
else
  log "⚠ جدول messages غير موجود في memory.db – سيتم تجاوزه."
fi

########################################
# 5) فحص الهوية داخل memory.db
########################################
log "[5] فحص الهوية (meta.identity_name) داخل memory.db..."
if table_exists "${MEM_DB}" "meta"; then
  sqlite3 "${MEM_DB}" "SELECT key, value FROM meta WHERE key IN ('identity_name','identity_role','schema_version');"
else
  log "⚠ جدول meta غير موجود – تأكد من تهيئة الذاكرة (Brain v2.0)."
fi
echo

########################################
# 6) فحص أي symlink داخل السويت (تقرير فقط)
########################################
log "[6] فحص symlinks داخل ${SUITE_DIR} (تقرير فقط – بدون تعديل)..."
SYMLINKS_FOUND=0
while IFS= read -r link; do
  if [ -n "$link" ]; then
    if [ "${SYMLINKS_FOUND}" -eq 0 ]; then
      echo "=== Symlinks تحت ${SUITE_DIR} ==="
    fi
    SYMLINKS_FOUND=1
    ls -l "$link"
  fi
done < <(find "${SUITE_DIR}" -type l 2>/dev/null || true)

if [ "${SYMLINKS_FOUND}" -eq 0 ]; then
  log "ℹ لا توجد symlinks داخل ${SUITE_DIR} (أو لم يتم العثور على أي منها)."
fi
echo

########################################
# 7) إعادة تشغيل الخدمات وربطها بالذاكرة الموحدة
########################################
log "[7] إعادة تشغيل خدمات SmartFriend Suite..."
SERVICES=(sf-memory.service sf-unified.service sf-bot.service sf-health.service)

for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}"; then
    log "⏳ systemctl restart ${svc} ..."
    if systemctl restart "${svc}"; then
      log "✅ ${svc} تم إعادة تشغيلها."
    else
      log "⚠ فشل في إعادة تشغيل ${svc} – راجع systemctl status."
    fi
  else
    log "ℹ الخدمة ${svc} غير معرفة في systemd (يُتجاوز)."
  fi
done

echo
log "[8] فحص Health HTTP endpoints..."

check_health(){
  local name="$1"
  local url="$2"
  if command -v curl >/dev/null 2>&1; then
    code="$(curl -s -o /dev/null -w '%{http_code}' "${url}" || echo "000")"
    if [ "${code}" = "200" ]; then
      log "✅ ${name}: UP (${url}) [HTTP ${code}]"
    else
      log "⚠ ${name}: NOT OK (${url}) [HTTP ${code}]"
    fi
  else
    log "⚠ curl غير متوفر – لا يمكن فحص ${name} (${url})."
  fi
}

check_health "sf-health"  "http://127.0.0.1:8210/health"
check_health "sf-memory"  "http://127.0.0.1:8214/health"
check_health "sf-unified" "http://127.0.0.1:8220/health"
check_health "ff-healthd" "http://127.0.0.1:9191/health"

echo
log "===== DONE: SmartFriend Suite Self Check & Unify (no symlink) ====="

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
ARCHIVE_DIR="${ARCHIVE_ROOT}/FULL_SUITE_SELFCHK_${TS}"

log "===== SmartFriend FULL Suite – Self Check + Run + Unify (NO symlink) ====="
log "SUITE_DIR   = ${SUITE_DIR}"
log "FF_DIR      = ${FF_DIR}"
log "DB_DIR      = ${DB_DIR}"
log "ARCHIVE_DIR = ${ARCHIVE_DIR}"
echo

mkdir -p "${ARCHIVE_DIR}"

########################################
# 0) معلومات أساسية عن النظام
########################################
log "[0] معلومات النظام السريعة:"
if command -v hostnamectl >/dev/null 2>&1; then
  hostnamectl
fi
echo
uptime || true
echo
df -h / || true
echo

########################################
# Helper: وجود جدول في SQLite
########################################
table_exists() {
  local db="$1"
  local tbl="$2"
  sqlite3 "${db}" "SELECT name FROM sqlite_master WHERE type='table' AND name='${tbl}';" 2>/dev/null | grep -qx "${tbl}"
}

########################################
# 1) فحص /opt/smartfriend-suite وقواعد البيانات
########################################
log "[1] فحص بنية السيوت وقواعد البيانات..."

if [ ! -d "${SUITE_DIR}" ]; then
  log "❌ مجلد السيوت غير موجود: ${SUITE_DIR}"
  exit 1
fi

if [ ! -d "${DB_DIR}" ]; then
  log "❌ مجلد قواعد بيانات السيوت غير موجود: ${DB_DIR}"
  exit 1
fi

echo ">> محتوى ${DB_DIR}:"
ls -la "${DB_DIR}"
echo

# smartfriend_unified.db
if [ -f "${UNIFIED_DB}" ]; then
  size_unified=$(du -h "${UNIFIED_DB}" | cut -f1)
  log "ℹ smartfriend_unified.db موجودة (حجمها ${size_unified}) – لن يتم لمسها."
else
  log "⚠ smartfriend_unified.db غير موجودة – فقط تقرير، لن يتم الإنشاء أو الحذف."
fi

# active_memory.db
if [ -f "${ACTIVE_DB}" ]; then
  size_active=$(du -h "${ACTIVE_DB}" | cut -f1)
  log "ℹ active_memory.db موجودة (حجمها ${size_active})."
else
  log "⚠ active_memory.db غير موجودة – سيتم الاعتماد على memory.db إن وُجدت."
fi

# memory.db
if [ -f "${MEM_DB}" ]; then
  size_mem=$(du -h "${MEM_DB}" | cut -f1)
  log "ℹ memory.db موجودة (حجمها ${size_mem})."
else
  if [ -f "${ACTIVE_DB}" ]; then
    log "ℹ memory.db غير موجودة – سيتم إنشاؤها من active_memory.db..."
    cp -a "${ACTIVE_DB}" "${MEM_DB}"
    log "✅ تم إنشاء memory.db من active_memory.db."
  else
    log "❌ لا يوجد لا memory.db ولا active_memory.db – لا يمكن متابعة الدمج."
    exit 1
  fi
fi
echo

########################################
# 2) Backup قبل أي تعديل على memory.db
########################################
log "[2] Backup كامل لـ memory.db قبل أي تعديل..."
cp -a "${MEM_DB}" "${ARCHIVE_DIR}/memory_before_fix.db"
log "✅ backup: ${ARCHIVE_DIR}/memory_before_fix.db"
echo

########################################
# 3) توحيد سكيمة جدول sessions (إضافة session_id إن لزم)
########################################
log "[3] فحص/إصلاح سكيمة sessions في memory.db..."

if table_exists "${MEM_DB}" "sessions"; then
  log "ℹ جدول sessions موجود – فحص الأعمدة..."
  echo "PRAGMA table_info('sessions') قبل التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');"
  echo

  if sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');" | awk -F'|' '{print $2}' | grep -qx "session_id"; then
    log "ℹ session_id موجود بالفعل – لا تعديل."
  else
    log "⚠ session_id غير موجود – إضافة العمود وملؤه من id..."
    sqlite3 "${MEM_DB}" <<'SQL'
ALTER TABLE sessions ADD COLUMN session_id TEXT;
UPDATE sessions SET session_id = id WHERE session_id IS NULL OR session_id = '';
CREATE INDEX IF NOT EXISTS idx_sessions_session_id ON sessions(session_id);
SQL
    log "✅ تم إضافة session_id + index."
  fi

  echo
  log "PRAGMA table_info('sessions') بعد التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('sessions');"
  echo
else
  log "⚠ جدول sessions غير موجود – يُتجاوز."
fi

########################################
# 4) توحيد سكيمة جدول messages (إضافة message_id إن لزم)
########################################
log "[4] فحص/إصلاح سكيمة messages في memory.db..."

if table_exists "${MEM_DB}" "messages"; then
  log "ℹ جدول messages موجود – فحص الأعمدة..."
  echo "PRAGMA table_info('messages') قبل التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');"
  echo

  if sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');" | awk -F'|' '{print $2}' | grep -qx "message_id"; then
    log "ℹ message_id موجود بالفعل – لا تعديل."
  else
    log "⚠ message_id غير موجود – إضافة العمود وملؤه من id..."
    sqlite3 "${MEM_DB}" <<'SQL'
ALTER TABLE messages ADD COLUMN message_id TEXT;
UPDATE messages SET message_id = id WHERE message_id IS NULL OR message_id = '';
CREATE INDEX IF NOT EXISTS idx_messages_message_id ON messages(message_id);
SQL
    log "✅ تم إضافة message_id + index."
  fi

  echo
  log "PRAGMA table_info('messages') بعد التعديل:"
  sqlite3 "${MEM_DB}" "PRAGMA table_info('messages');"
  echo
else
  log "⚠ جدول messages غير موجود – يُتجاوز."
fi

########################################
# 5) فحص الهوية داخل memory.db
########################################
log "[5] فحص هوية Brain داخل meta في memory.db..."
if table_exists "${MEM_DB}" "meta"; then
  sqlite3 "${MEM_DB}" "SELECT key, value FROM meta WHERE key IN ('identity_name','identity_role','schema_version');"
else
  log "⚠ جدول meta غير موجود – الذاكرة تحتاج تهيئة Brain v2.0."
fi
echo

########################################
# 6) فحص symlinks داخل السيوت (تقرير فقط)
########################################
log "[6] فحص symlinks داخل ${SUITE_DIR} (تقرير فقط – بدون إنشاء/حذف)..."
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
# 7) حصر كل خدمات sf-* و ff-* وتشغيلها
########################################
log "[7] حصر وتشغيل جميع خدمات sf-* و ff-* (داخل المنظومة)..."

get_units_by_prefix() {
  local prefix="$1"
  systemctl list-unit-files "${prefix}*.service" --no-legend 2>/dev/null | awk '{print $1}' || true
}

SF_UNITS=$(get_units_by_prefix "sf-")
FF_UNITS=$(get_units_by_prefix "ff-")

echo "=== خدمات SmartFriend (sf-*.service) ==="
if [ -n "${SF_UNITS}" ]; then
  echo "${SF_UNITS}"
else
  echo "(لا يوجد وحدات sf-*.service معرّفة في systemd)"
fi
echo

echo "=== خدمات FFactory (ff-*.service) ==="
if [ -n "${FF_UNITS}" ]; then
  echo "${FF_UNITS}"
else
  echo "(لا يوجد وحدات ff-*.service معرّفة في systemd)"
fi
echo

restart_and_report(){
  local unit="$1"

  if [ -z "${unit}" ]; then
    return 0
  fi

  if ! systemctl list-unit-files | grep -q "^${unit}"; then
    log "ℹ ${unit} غير معرّفة في systemd – يُتجاوز."
    return 0
  fi

  local enabled_state
  enabled_state="$(systemctl is-enabled "${unit}" 2>/dev/null || echo "unknown")"
  local active_state
  active_state="$(systemctl is-active "${unit}" 2>/dev/null || echo "unknown")"

  log "⏳ ${unit}: enabled=${enabled_state}, active=${active_state} – سيتم restart..."
  if systemctl restart "${unit}"; then
    sleep 1
    local new_state
    new_state="$(systemctl is-active "${unit}" 2>/dev/null || echo "unknown")"
    log "✅ ${unit}: الحالة بعد restart = ${new_state}"
  else
    log "⚠ فشل في restart لـ ${unit} – راجع systemctl status ${unit}"
  fi
}

# إعادة تشغيل كل sf-*
for u in ${SF_UNITS}; do
  restart_and_report "${u}"
done

# إعادة تشغيل كل ff-*
for u in ${FF_UNITS}; do
  restart_and_report "${u}"
done

echo

########################################
# 8) Health checks للخدمات الرئيسية
########################################
log "[8] فحص Health HTTP للخدمات الرئيسية..."

check_health(){
  local name="$1"
  local url="$2"

  if ! command -v curl >/dev/null 2>&1; then
    log "⚠ curl غير متوفر – لا يمكن فحص ${name} (${url})."
    return 0
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "${url}" || echo "000")"
  if [ "${code}" = "200" ]; then
    log "✅ ${name}: UP (${url}) [HTTP ${code}]"
  else
    log "⚠ ${name}: NOT OK (${url}) [HTTP ${code}]"
  fi
}

check_health "sf-health"  "http://127.0.0.1:8210/health"
check_health "sf-memory"  "http://127.0.0.1:8214/health"
check_health "sf-unified" "http://127.0.0.1:8220/health"
check_health "ff-healthd" "http://127.0.0.1:9191/health"

echo
log "===== DONE: FULL SmartFriend Suite Self Check + Run + Unify (NO symlink) ====="

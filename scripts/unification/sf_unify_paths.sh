#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"
VAR_DIR="${APP_ROOT}/var"
DB_DIR="${VAR_DIR}/db"
KNOW_DIR="${VAR_DIR}/knowledge"
MEM_RAW_DIR="${VAR_DIR}/memory"
LOG_DIR="${VAR_DIR}/logs"
REPORT_DIR="${APP_ROOT}/reports"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_ROOT="/root/sf_unify_backup_${TS}"
MANIFEST="${REPORT_DIR}/sf_unify_manifest_${TS}.txt"
REF_REPORT="${REPORT_DIR}/sf_old_paths_report_${TS}.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

echo "============================================================"
echo "   🔁 SmartFriend Suite - Unify DB Paths (NO symlinks)"
echo "   Timestamp: ${TS}"
echo "============================================================"
echo

log "1) إنشاء هيكل var/ القياسي تحت ${APP_ROOT}"

mkdir -p "${APP_ROOT}"
mkdir -p "${VAR_DIR}" "${DB_DIR}" "${KNOW_DIR}" "${MEM_RAW_DIR}" "${LOG_DIR}" "${REPORT_DIR}"
mkdir -p "${BACKUP_ROOT}"

log "إنشاء ملف المانيفيست: ${MANIFEST}"
{
  echo "SmartFriend Suite - Unify DB Paths Manifest"
  echo "Timestamp: ${TS}"
  echo "APP_ROOT=${APP_ROOT}"
  echo "VAR_DIR=${VAR_DIR}"
  echo "DB_DIR=${DB_DIR}"
  echo "BACKUP_ROOT=${BACKUP_ROOT}"
  echo
  echo "== Moved DB Files =="
} > "${MANIFEST}"

move_db(){
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ -f "${src}" ]; then
    log "نقل قاعدة البيانات (${label}) من: ${src}"
    local backup="${BACKUP_ROOT}/$(basename "${src}")"
    cp -p "${src}" "${backup}"
    log "  • نسخة احتياطية: ${backup}"
    mv "${src}" "${dst}"
    log "  • المسار الجديد: ${dst}"
    echo "${label}: ${src} -> ${dst} (backup: ${backup})" >> "${MANIFEST}"
  else
    warn "تخطي (${label}) - غير موجود: ${src}"
  fi
}

log "2) نقل قواعد بيانات الذاكرة داخل ${DB_DIR} (بدون symlinks)"

move_db "${APP_ROOT}/memory.db"              "${DB_DIR}/memory.db"              "memory.db"
move_db "${APP_ROOT}/smart_core_memory.db"   "${DB_DIR}/smart_core_memory.db"   "smart_core_memory.db"
move_db "${APP_ROOT}/unified_memory.db"      "${DB_DIR}/unified_memory.db"      "unified_memory.db"
move_db "${APP_ROOT}/smartfriend_unified.db" "${DB_DIR}/smartfriend_unified.db" "smartfriend_unified.db"

log "3) نقل قواعد بيانات SmartFrind القديمة (legacy) - إن وُجدت"

if [ -d "/opt/smartfrind" ]; then
  move_db "/opt/smartfrind/knowledge.db" "${DB_DIR}/smartfrind_knowledge.db" "smartfrind.knowledge.db"
  move_db "/opt/smartfrind/memory.db"    "${DB_DIR}/smartfrind_memory.db"    "smartfrind.memory.db"
else
  warn "مجلد /opt/smartfrind غير موجود - تخطي نقل قواعد legacy الافتراضية"
fi

log "4) فحص الإشارات للمسارات القديمة وكتابة تقرير: ${REF_REPORT}"

OLD_PATTERNS=(
  "/opt/smartfriend-suite/memory.db"
  "/opt/smartfriend-suite/smart_core_memory.db"
  "/opt/smartfriend-suite/unified_memory.db"
  "/opt/smartfriend-suite/smartfriend_unified.db"
  "/opt/smartfrind/knowledge.db"
  "/opt/smartfrind/memory.db"
)

{
  echo "SmartFriend Suite - Old Paths Reference Report"
  echo "Timestamp: ${TS}"
  echo
  echo "البحث في:"
  echo "  - /etc/systemd/system"
  echo "  - ${APP_ROOT}"
  echo "  - /opt/smartfrind (إن وُجد)"
  echo
} > "${REF_REPORT}"

for pat in "${OLD_PATTERNS[@]}"; do
  echo "------------------------------" >> "${REF_REPORT}"
  echo "Pattern: ${pat}" >> "${REF_REPORT}"
  matches=$(grep -R --line-number --fixed-strings "${pat}" /etc/systemd/system "${APP_ROOT}" /opt/smartfrind 2>/dev/null || true)
  if [ -n "${matches}" ]; then
    echo "${matches}" >> "${REF_REPORT}"
  else
    echo "(no matches)" >> "${REF_REPORT}"
  fi
  echo >> "${REF_REPORT}"
done

log "5) ملخص:"
log "  • BACKUP_ROOT: ${BACKUP_ROOT}"
log "  • مانيفيست المسارات: ${MANIFEST}"
log "  • تقرير المراجع القديمة: ${REF_REPORT}"

echo
echo "⚠ مهم:"
echo "  - تم نقل قواعد البيانات فعليًا إلى var/db بدون إنشاء أي symlink."
echo "  - أي خدمة ما زالت تشير للمسارات القديمة تحتاج تعديل في المرحلة التالية."
echo "============================================================"

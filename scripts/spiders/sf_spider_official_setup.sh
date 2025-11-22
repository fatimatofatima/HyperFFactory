#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

APP_ROOT="/opt/smartfriend-suite"

APPS_DIR="${APP_ROOT}/apps"
HARVESTER_DIR="${APPS_DIR}/harvester"
SPIDER_DIR="${HARVESTER_DIR}/spider"

VAR_DIR="${APP_ROOT}/var"
KNOW_DIR="${VAR_DIR}/knowledge"
LOG_VAR_DIR="${VAR_DIR}/logs"

REPORT_DIR="${APP_ROOT}/reports"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_ROOT="/root/sf_spider_backup_${TS}"
MANIFEST="${REPORT_DIR}/sf_spider_manifest_${TS}.txt"
CANDIDATES_REPORT="${REPORT_DIR}/sf_spider_candidates_${TS}.txt"
UNITS_REPORT="${REPORT_DIR}/sf_spider_units_${TS}.txt"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }
info()  { echo -e "${CYAN}[ℹ] $*${NC}"; }

echo "================================================================"
echo "   🕸  SmartFriend Spider – Official Suite Setup"
echo "   Timestamp: ${TS}"
echo "================================================================"
echo

log "1) إنشاء مسارات سبايدر الرسمية داخل السويت"

mkdir -p "${APP_ROOT}"
mkdir -p "${APPS_DIR}" "${HARVESTER_DIR}" "${SPIDER_DIR}"
mkdir -p "${KNOW_DIR}/raw_spider"
mkdir -p "${LOG_VAR_DIR}/spider"
mkdir -p "${REPORT_DIR}" "${BACKUP_ROOT}"

log "إنشاء ملف المانيفيست: ${MANIFEST}"
{
  echo "SmartFriend Suite - Spider Manifest"
  echo "Timestamp: ${TS}"
  echo "APP_ROOT=${APP_ROOT}"
  echo "SPIDER_DIR=${SPIDER_DIR}"
  echo "RAW_SPIDER_DIR=${KNOW_DIR}/raw_spider"
  echo "SPIDER_LOG_DIR=${LOG_VAR_DIR}/spider"
  echo "BACKUP_ROOT=${BACKUP_ROOT}"
  echo
  echo "== Actions =="
} > "${MANIFEST}"

log "2) البحث عن مجلدات لها علاقة بـ spider تحت /opt (تحضير للهجرة)"

CANDIDATES=$(find /opt -maxdepth 5 -type d \( \
    -iname "smartfriend-spider" -o \
    -iname "smartfrind-spider" -o \
    -iname "smartfriend_spider" -o \
    -iname "smartfrind_spider" -o \
    -iname "*spider*" \
  \) 2>/dev/null | sort -u || true)

echo "SmartFriend Suite - Spider Candidates" > "${CANDIDATES_REPORT}"
echo "Timestamp: ${TS}" >> "${CANDIDATES_REPORT}"
echo >> "${CANDIDATES_REPORT}"

if [ -z "${CANDIDATES}" ]; then
  warn "لم يتم العثور على مجلدات spider تحت /opt – لن يتم نسخ أي كود الآن."
  echo "(no spider directories found under /opt)" >> "${CANDIDATES_REPORT}"
else
  log "تم العثور على مجلدات مرشحة لـ spider – كتابة تقرير بالمسارات."
  echo "Found spider-like directories:" >> "${CANDIDATES_REPORT}"
  echo "${CANDIDATES}" >> "${CANDIDATES_REPORT}"
fi

log "3) اختيار مجلد سبايدر أساسي (لو موجود بشكل واضح)"

PRIMARY=""
for cand in ${CANDIDATES}; do
  base="$(basename "$cand" | tr '[:upper:]' '[:lower:]')"
  case "${base}" in
    smartfriend-spider|smartfrind-spider|smartfriend_spider|smartfrind_spider)
      PRIMARY="$cand"
      break
      ;;
  esac
done

if [ -n "${PRIMARY}" ]; then
  log "استخدام المجلد الأساسي لسبايدر: ${PRIMARY}"
  echo "PRIMARY_SPIDER_DIR=${PRIMARY}" >> "${MANIFEST}"

  log "نسخ كود سبايدر إلى: ${SPIDER_DIR}"
  if [ -d "${SPIDER_DIR}" ] && [ "$(ls -A "${SPIDER_DIR}" 2>/dev/null)" ]; then
    backup_dir="${BACKUP_ROOT}/spider_existing_${TS}"
    log "  • سبايدر موجود مسبقًا داخل السويت – عمل نسخة احتياطية في: ${backup_dir}"
    mkdir -p "${backup_dir}"
    cp -a "${SPIDER_DIR}/." "${backup_dir}/"
  fi

  rm -rf "${SPIDER_DIR}"
  mkdir -p "${SPIDER_DIR}"
  cp -a "${PRIMARY}/." "${SPIDER_DIR}/"

  echo "COPIED: ${PRIMARY} -> ${SPIDER_DIR}" >> "${MANIFEST}"
else
  warn "لا يوجد مجلد وحيد/واضح باسم smartfriend-spider أو smartfrind-spider – لن يتم نسخ كود تلقائيًا."
  echo "PRIMARY_SPIDER_DIR=(none detected, no auto-copy)" >> "${MANIFEST}"
fi

log "4) فحص وحدات systemd التي تشير إلى سبايدر (تقرير فقط، بدون تعديل)"

echo "SmartFriend Suite - Spider Systemd Units" > "${UNITS_REPORT}"
echo "Timestamp: ${TS}" >> "${UNITS_REPORT}"
echo >> "${UNITS_REPORT}"

if [ -d /etc/systemd/system ]; then
  SPIDER_UNITS=$(grep -R --line-number --ignore-case "spider" /etc/systemd/system 2>/dev/null || true)
  if [ -n "${SPIDER_UNITS}" ]; then
    log "تم العثور على إشارات لـ spider داخل /etc/systemd/system – راجع تقرير الوحدات."
    echo "${SPIDER_UNITS}" >> "${UNITS_REPORT}"
  else
    warn "لا توجد إشارات لـ spider داخل /etc/systemd/system حاليًا."
    echo "(no spider-related systemd references found)" >> "${UNITS_REPORT}"
  fi
else
  warn "/etc/systemd/system غير موجود؟ تم التخطي."
  echo "(/etc/systemd/system missing?)" >> "${UNITS_REPORT}"
fi

echo >> "${MANIFEST}"
echo "Reports:" >> "${MANIFEST}"
echo "  - Spider candidates: ${CANDIDATES_REPORT}" >> "${MANIFEST}"
echo "  - Spider systemd units: ${UNITS_REPORT}" >> "${MANIFEST}"

log "5) ملخص:"
log "  • مجلد سبايدر الرسمي: ${SPIDER_DIR}"
log "  • مجلد raw_spider للمعرفة: ${KNOW_DIR}/raw_spider"
log "  • لوجات سبايدر: ${LOG_VAR_DIR}/spider"
log "  • BACKUP_ROOT: ${BACKUP_ROOT}"
log "  • مانيفيست: ${MANIFEST}"
log "  • تقرير المرشحين: ${CANDIDATES_REPORT}"
log "  • تقرير وحدات systemd: ${UNITS_REPORT}"

echo
echo "⚠ مهم:"
echo "  - لم يتم تعديل أي وحدة systemd أو تشغيل سبايدر تلقائيًا."
echo "  - لو PRIMARY_SPIDER_DIR فارغ في المانيفيست، يبقى محتاج تختار يدويًا مجلد السبيدر قبل أي خطوة دمج لاحقة."
echo "================================================================"

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

LEGACY_DIRS=(
  "/opt/SmartFriend"
  "/opt/SmartFrind_Miracle"
  "/opt/smartfrind_unified"
  "/opt/MyFriend"
  "/opt/BRAIN_CORE"
)

LEGACY_BACKUP_GLOBS=(
  "/opt/smartfrind_backup_*"
  "/opt/smartfriend-suite-backup*"
)

ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/LEGACY_PROJECTS_${TS}"

log "Stage 2 – Archive & move legacy SmartFriend projects"
log "ARCHIVE_DIR = ${ARCHIVE_DIR}"

mkdir -p "${ARCHIVE_DIR}"

echo
echo "==============================================="
log "نقل المشاريع الأساسية إلى الأرشيف"
echo "==============================================="

for d in "${LEGACY_DIRS[@]}"; do
  if [ -d "$d" ]; then
    log "Moving DIR: $d -> ${ARCHIVE_DIR}/"
    mv "$d" "${ARCHIVE_DIR}/" || log "WARN: فشل نقل $d"
  else
    log "SKIP (not found): $d"
  fi
done

echo
echo "==============================================="
log "نقل مجلدات/ملفات الباك-أب إلى الأرشيف"
echo "==============================================="

for g in "${LEGACY_BACKUP_GLOBS[@]}"; do
  matches=( $g )
  if [ "${#matches[@]}" -gt 0 ] && [ -e "${matches[0]}" ]; then
    for m in "${matches[@]}"; do
      if [ -d "$m" ] || [ -f "$m" ]; then
        log "Moving: $m -> ${ARCHIVE_DIR}/"
        mv "$m" "${ARCHIVE_DIR}/" || log "WARN: فشل نقل $m"
      fi
    done
  else
    log "SKIP (no match): $g"
  fi
done

echo
echo "==============================================="
log "ملخص بعد النقل"
echo "==============================================="
log "محتوى الأرشيف:"
ls -la "${ARCHIVE_DIR}" || true

echo
log "المشاريع المتبقية تحت /opt:"
ls -la /opt

log "Stage 2 DONE – لا يوجد حذف، فقط نقل للأرشيف."

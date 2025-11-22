#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

OPT_DIR="/opt"
ARCHIVE_ROOT="/opt/COMPLETE_CODE_BACKUP"
TS="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_DIR="${ARCHIVE_ROOT}/LEGACY_PROJECTS_${TS}"

log "تنفيذ دمج/تجميع مشاريع SmartFriend القديمة في أرشيف واحد"
log "OPT_DIR      = ${OPT_DIR}"
log "ARCHIVE_DIR  = ${ARCHIVE_DIR}"
echo

mkdir -p "$ARCHIVE_DIR"

cd "$OPT_DIR"

# قائمة المرشحين نفسها من الـ PLAN
CANDIDATES=()

for d in SmartFriend smartfrind_unified SmartFrind_Miracle MyFriend BRAIN_CORE \
         smartfriend-suite-backup smartfriend-suite-backup-* \
         smartfrind_backup_* \
         MyFriend_* \
         REAL_COMPLETE_INDEX_BACKUP; do
  if [ -d "$d" ]; then
    CANDIDATES+=("$d")
  fi
done

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  log "لا يوجد شيء لنقله – لا توجد مجلدات مطابقة للأنماط."
  exit 0
fi

log "سيتم نقل المجلدات التالية إلى الأرشيف:"
for d in "${CANDIDATES[@]}"; do
  echo "  - $OPT_DIR/$d  ->  $ARCHIVE_DIR/$d"
done
echo

# التنفيذ الفعلي للنقل
for d in "${CANDIDATES[@]}"; do
  log "Moving: $OPT_DIR/$d -> $ARCHIVE_DIR/$d"
  mv "$d" "$ARCHIVE_DIR/" || log "WARN: فشل نقل $d"
done

echo
log "محتوى /opt بعد الدمج (جزئي):"
ls -1

echo
log "محتوى الأرشيف الجديد:"
ls -1 "$ARCHIVE_DIR" || true

log "انتهى الدمج الفعلي: كل مشاريع SmartFriend القديمة أصبحت مجمعة تحت ${ARCHIVE_DIR}"
log "الإنتاج المعتمد الآن: smartfriend-suite + ffactory (بالإضافة إلى COMPLETE_CODE_BACKUP, report, secure ... كبنية دعم فقط)."

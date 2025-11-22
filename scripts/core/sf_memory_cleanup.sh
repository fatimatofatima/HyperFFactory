#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

MODE="${1:-list}"

BASE="/opt/smartfriend-suite/var/db"

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== SmartFriend Memory Backups Cleanup ====="
log "BASE = $BASE"
log "MODE = $MODE"

if [ ! -d "$BASE" ]; then
  log "ERROR: المجلد $BASE غير موجود. خروج."
  exit 1
fi

# الأنماط المستهدفة: فقط نسخ الباك اب والـ legacy
PATTERNS=(
  "memory.db.bak_*"
  "smart_core_memory.db.bak_*"
  "unified_memory.db.bak_*"
  "active_memory.db.bak_*"
  "memory.db.legacy_*"
  "smart_core_memory.db.legacy_*"
  "unified_memory.db.legacy_*"
)

CANDIDATES=()

for pat in "${PATTERNS[@]}"; do
  for f in "$BASE"/$pat; do
    [ -e "$f" ] || continue
    CANDIDATES+=( "$f" )
  done
done

if [ "${#CANDIDATES[@]}" -eq 0 ]; then
  log "لا توجد ملفات نسخ احتياطية أو legacy مطابقة للأنماط المحددة."
  log "لا شيء للتنظيف."
  exit 0
fi

log "عدد الملفات المستهدفة: ${#CANDIDATES[@]}"

echo
log "الملفات التي سيتم التعامل معها:"
for f in "${CANDIDATES[@]}"; do
  ls -l "$f" || true
done
echo

case "$MODE" in
  list)
    log "وضع المعاينة فقط (list): لم يتم حذف أي ملف."
    ;;

  delete)
    log "وضع الحذف الفعلي (delete): سيتم حذف الملفات أعلاه..."
    for f in "${CANDIDATES[@]}"; do
      log "حذف: $f"
      rm -f -- "$f" || log "تحذير: فشل حذف $f"
    done
    log "تم تنفيذ عملية التنظيف."
    ;;

  *)
    log "استخدام غير صحيح."
    echo "Usage:"
    echo "  bash /root/sf_memory_cleanup.sh list   # عرض فقط"
    echo "  bash /root/sf_memory_cleanup.sh delete # حذف النسخ الاحتياطية والـ legacy"
    exit 1
    ;;
esac

echo
log "ملاحظة: لم يتم لمس أي من الملفات الأساسية التالية:"
log "  - active_memory.db"
log "  - memory.db (symlink الحالي)"
log "  - smart_core_memory.db (symlink الحالي)"
log "  - smartfriend_unified.db (كوربس المعرفة الرئيسي)"
log "===== DONE ====="

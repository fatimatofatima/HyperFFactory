#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

OPT_DIR="/opt"

log "خطة دمج/تجميع مشاريع SmartFriend القديمة (PLAN ONLY)"
log "OPT_DIR = ${OPT_DIR}"
echo

cd "$OPT_DIR"

echo "=== المجلدات الحالية في /opt (مختصرة) ==="
ls -1
echo

echo "=== المجلدات المرشحة للأرشفة تحت COMPLETE_CODE_BACKUP ==="
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
  log "لا توجد مجلدات مرشحة حسب الأنماط المحددة."
else
  for d in "${CANDIDATES[@]}"; do
    echo "$OPT_DIR/$d"
  done
fi

echo
echo "ملاحظة:"
echo "- هذا السكربت لا ينقل ولا يحذف أي شيء."
echo "- الإنتاج المعتمد سيظل في: smartfriend-suite + ffactory."

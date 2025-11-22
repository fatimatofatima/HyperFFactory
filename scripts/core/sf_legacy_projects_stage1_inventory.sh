#!/usr/bin/env bash
set -Eeuo pipefail

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

echo "=================================================="
log "Stage 1 – Legacy SmartFriend projects inventory"
echo "=================================================="
echo

echo ">> المشاريع المرشّحة للأرشفة:"
for d in "${LEGACY_DIRS[@]}"; do
  if [ -d "$d" ]; then
    du -sh "$d" || true
  else
    echo "MISSING (ok): $d"
  fi
done

echo
echo ">> باك-أب المرشّحة للأرشفة (أنماط):"
for g in "${LEGACY_BACKUP_GLOBS[@]}"; do
  matches=( $g )
  if [ "${#matches[@]}" -gt 0 ] && [ -e "${matches[0]}" ]; then
    for m in "${matches[@]}"; do
      if [ -d "$m" ] || [ -f "$m" ]; then
        du -sh "$m" || ls -l "$m"
      fi
    done
  else
    echo "NO MATCH: $g"
  fi
done

echo
echo ">> ملحوظة: لا يوجد نقل أو حذف في Stage 1؛ هذا جرد فقط."
echo "=================================================="

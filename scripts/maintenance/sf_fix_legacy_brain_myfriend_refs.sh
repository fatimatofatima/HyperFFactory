#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_audit"
LOG="${OUT_DIR}/fix_legacy_brain_myfriend_${TS}.log"
BACKUP_DIR="${OUT_DIR}/unit_backups_${TS}"
DRY_RUN="${DRY_RUN:-1}"

mkdir -p "$OUT_DIR" "$BACKUP_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
sec(){ echo -e "\n===== $* =====" | tee -a "$LOG"; }

sec "Scan systemd units for /opt/BRAIN_CORE or /opt/MyFriend"

mapfile -t UNITS < <(grep -RIl "/opt/BRAIN_CORE\|/opt/MyFriend" /etc/systemd/system 2>/dev/null || true)

if [ "${#UNITS[@]}" -eq 0 ]; then
  log "No systemd unit files reference /opt/BRAIN_CORE or /opt/MyFriend."
  log "Nothing to fix."
  exit 0
fi

log "Found ${#UNITS[@]} unit file(s):"
printf '  - %s\n' "${UNITS[@]}" | tee -a "$LOG"

if [ "$DRY_RUN" = "1" ]; then
  sec "DRY-RUN: showing affected lines only (no changes)"
  for u in "${UNITS[@]}"; do
    log "--- $u ---"
    grep -n "/opt/BRAIN_CORE\|/opt/MyFriend" "$u" | tee -a "$LOG" || true
  done
  log "No modifications applied. To actually patch PYTHONPATH and similar lines:"
  log "  DRY_RUN=0 bash /root/sf_fix_legacy_brain_myfriend_refs.sh"
  exit 0
fi

sec "APPLY MODE: patching unit files (backups first)"

for u in "${UNITS[@]}"; do
  b="${BACKUP_DIR}/$(basename "$u").${TS}"
  log "Backing up $u -> $b"
  cp -a "$u" "$b"

  log "Patching $u (removing :/opt/BRAIN_CORE and :/opt/MyFriend variants from paths)"
  # نحذف ظهورها كبادئة أو كلاحقة داخل متغيرات PATH/PYTHONPATH
  sed -E -i \
    -e 's#:/opt/BRAIN_CORE##g' \
    -e 's#/opt/BRAIN_CORE:##g' \
    -e 's#:/opt/MyFriend##g' \
    -e 's#/opt/MyFriend:##g' \
    "$u"

  log "New lines with old paths (should be empty ideally):"
  grep -n "/opt/BRAIN_CORE\|/opt/MyFriend" "$u" || log "  (none)"
done

sec "Reload systemd and suggest restarts"

log "Running: systemctl daemon-reload"
systemctl daemon-reload

log "راجع يدويًا الوحدات المتأثرة ثم أعد تشغيل الخدمات المرتبطة (ffactory وغيره) مثلاً:"
log "  systemctl restart ffactory.service  # إن وجد"
log "  systemctl restart sf-memory.service # إن كان فعّالاً"

log "Backups in: $BACKUP_DIR"
log "Log file:  $LOG"

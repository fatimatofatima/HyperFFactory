#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_reports"
LOG="${OUT_DIR}/sf_audit_opt_roots_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "=== SmartFriend OPT ROOTS AUDIT (physical layout / duplicates) ==="
log

# الجذور المتوقع وجودها (لن يتم الفشل لو بعضها غير موجود)
CANDIDATES=(
  "/opt/smartfriend-suite"
  "/opt/SmartFriend"
  "/opt/smartfrind_unified"
  "/opt/SmartFrind_Miracle"
  "/opt/ULTIMATE_FUSION"
  "/opt/portsboard"
  "/opt/BRAIN_CORE"
  "/opt/MyFriend"
)

log "1) High-level info for known roots under /opt"
for d in "${CANDIDATES[@]}"; do
  if [ -d "$d" ]; then
    log "--- ROOT: $d ---"
    du -sh "$d" 2>/dev/null | sed 's/^/SIZE: /' | tee -a "$LOG" || true
    stat -c 'MTIME: %y' "$d" 2>/dev/null | tee -a "$LOG" || true

    # وجود venv / app / docker-compose / git
    for sub in app venv env .venv docker-compose.yml docker-compose.yaml requirements.txt pyproject.toml; do
      if [ -e "$d/$sub" ]; then
        echo "HAS: $sub" | tee -a "$LOG"
      fi
    done
    if [ -d "$d/.git" ]; then
      echo "HAS: .git repo" | tee -a "$LOG"
    fi

    # إحصاء سريع للملفات البرمجية
    PY_COUNT=$(find "$d" -type f -name '*.py' 2>/dev/null | wc -l || echo 0)
    SH_COUNT=$(find "$d" -type f -name '*.sh' 2>/dev/null | wc -l || echo 0)
    echo "FILES: ${PY_COUNT}x .py, ${SH_COUNT}x .sh" | tee -a "$LOG"

    echo | tee -a "$LOG"
  fi
done

log
log "2) Systemd units referencing those roots (by path)"
SYSTEMD_DIRS="/etc/systemd/system /lib/systemd/system"
for d in "${CANDIDATES[@]}"; do
  if [ -d "$d" ]; then
    log "--- GREP in units for path: $d ---"
    grep -RIl --exclude-dir='*.wants' --exclude='*.bak*' "$d" $SYSTEMD_DIRS 2>/dev/null | sort | tee -a "$LOG" || echo "  (no direct references)" | tee -a "$LOG"
    echo | tee -a "$LOG"
  fi
done

log
log "3) Quick process scan by name (ps aux | grep)"
PATTERN='SmartFriend|smartfriend-suite|smartfrind_unified|SmartFrind_Miracle|ULTIMATE_FUSION|BRAIN_CORE|MyFriend|portsboard'
ps aux | egrep -i "$PATTERN" | egrep -v 'egrep|sf_audit_opt_roots' || echo "  (no matching processes)" | tee -a "$LOG"

log
log "4) Summary:"
log " - LOG file: $LOG"
log " - Use this report to decide أي جذور قديمة يمكن أرشفتها أو حذفها بعد مراجعة الكود."
log " - لا يقوم السكربت بأي حذف أو تعديل، فقط فحص."
log "=== END OF AUDIT (OPT ROOTS) ==="

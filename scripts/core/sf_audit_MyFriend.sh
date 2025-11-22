#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE="/opt/MyFriend"
TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_reports"
LOG="${OUT_DIR}/sf_audit_MyFriend_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
sec(){ echo -e "\n===== $* =====" | tee -a "$LOG"; }

if [ ! -d "$BASE" ]; then
  log "DIR $BASE not found. Nothing to audit."
  exit 0
fi

sec "Basic info"
ls -ld "$BASE" | tee -a "$LOG"
du -sh "$BASE" 2>/dev/null | tee -a "$LOG" || true

sec "Top-level tree (depth 2)"
find "$BASE" -maxdepth 2 -mindepth 1 -printf '%y %p\n' 2>/dev/null | tee -a "$LOG" || true

sec "Virtualenvs"
find "$BASE" -maxdepth 5 -type d -name "venv" 2>/dev/null | tee -a "$LOG" || true

for v in $(find "$BASE" -maxdepth 5 -type d -name "venv" 2>/dev/null); do
  log "--- VENV: $v ---"
  if [ -x "$v/bin/python" ]; then
    "$v/bin/python" -V 2>&1 | tee -a "$LOG" || true
  fi
  if [ -x "$v/bin/pip" ]; then
    "$v/bin/pip" list 2>/dev/null | head -n 30 | tee -a "$LOG" || true
  fi
done

sec "Requirements / dependency files"
find "$BASE" -maxdepth 6 -type f \( -name "requirements*.txt" -o -name "pyproject.toml" -o -name "setup.cfg" \) 2>/dev/null \
  | tee -a "$LOG" || true

sec "Databases / storage files"
find "$BASE" -maxdepth 6 -type f \( -name "*.db" -o -name "*.sqlite*" -o -name "*.json" \) 2>/dev/null \
  | tee -a "$LOG" || true

sec "Python packages/modules (top-level)"
find "$BASE" -maxdepth 3 -type d -name "*.egg-info" -o -maxdepth 3 -type f -name "__init__.py" 2>/dev/null \
  | tee -a "$LOG" || true

sec "Search for smartfriend/smartfrind naming (potential overlap)"
/bin/grep -R -n -E 'smartfriend|smartfrind' "$BASE" 2>/dev/null | head -n 80 | tee -a "$LOG" || true

sec "systemd / cron references to MyFriend"
/bin/grep -R --line-number 'MyFriend' /etc/systemd/system /lib/systemd/system 2>/dev/null | tee -a "$LOG" || true
/bin/grep -R --line-number 'MyFriend' /etc/cron* 2>/dev/null | tee -a "$LOG" || true

sec "Summary (for decision)"
log "1) Use this report لمقارنة تصميم MyFriend مع السويت الموحد."
log "2) لو لا توجد أي مراجع تشغيلية (systemd/cron/nginx) وكان الكود قديم/مكرر:"
log "   → يمكن أرشفته أو حذفه بعد باك أب."
log
log "Report: ${LOG}"

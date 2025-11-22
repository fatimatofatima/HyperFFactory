#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_audit"
LOG="${OUT_DIR}/sf_audit_unified_state_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
sec(){ echo -e "\n===== $* =====" | tee -a "$LOG"; }

sec "Meta"
log "Audit time: ${TS}"
log "Host: $(hostname)"
log "Kernel: $(uname -r)"
log "Uptime: $(uptime -p || true)"

sec "Disk / Memory"
df -h / | tee -a "$LOG"
echo >>"$LOG"
free -h | tee -a "$LOG"

sec "Key Directories (exists + size)"
for d in \
  /opt/smartfriend-suite \
  /opt/smartfriend-suite/smartfriend \
  /opt/smartfriend-suite/smartfriend/app \
  /opt/smartfriend-suite/smartfriend/venv \
  /opt/smartfriend-suite/smartfrind \
  /opt/smartfriend-suite/smartfrind/venv \
  /opt/ffactory \
  /opt/BRAIN_CORE \
  /opt/COMPLETE_CODE_BACKUP \
  /opt/report
do
  if [ -e "$d" ]; then
    log "[OK] $d"
    du -sh "$d" 2>/dev/null | tee -a "$LOG" || true
  else
    log "[MISS] $d (not found)"
  fi
  echo | tee -a "$LOG"
done

sec "Databases (size)"
for f in \
  /opt/smartfriend-suite/var/db/smartfriend_unified.db \
  /opt/BRAIN_CORE/memory/memory.db \
  /opt/BRAIN_CORE/memory/shared.db
do
  if [ -f "$f" ]; then
    ls -lh "$f" | tee -a "$LOG"
  else
    log "[MISS-DB] $f"
  fi
done

sec "Systemd units (SmartFriend / SmartFrind / ffactory)"
systemctl list-units 'smartfriend-*' 'smartfrind-*' 'ffactory*' --type=service --no-pager --plain | tee -a "$LOG" || true

sec "Systemd env paths referencing BRAIN_CORE / MyFriend"
grep -RIl "/opt/BRAIN_CORE\|/opt/MyFriend" /etc/systemd/system 2>/dev/null | tee -a "$LOG" || echo "no matches" | tee -a "$LOG"

sec "Critical ports (8210-8220, 8000, 5052, 5432, 6379)"
(ss -tulpn 2>/dev/null | grep -E '(:8210|:8211|:8212|:8213|:8219|:8220|:8000|:5052|:5432|:6379)' || true) | tee -a "$LOG"

sec "Process summary (smartfriend/smartfrind/ffactory)"
ps aux | grep -Ei 'smartfriend|smartfrind|ffactory' | grep -v grep | tee -a "$LOG" || true

log "Audit complete. Full report: $LOG"

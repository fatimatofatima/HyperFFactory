#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_audit"
LOG="${OUT_DIR}/sf_services_full_audit_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
sec(){ echo -e "\n===== $* =====" | tee -a "$LOG"; }

sec "Basic host info"
log "Host: $(hostname)"
log "Kernel: $(uname -r)"
log "Uptime: $(uptime -p || true)"
log "Load:   $(uptime || true)"

sec "Disk / RAM summary"
df -h / | tee -a "$LOG"
free -h | tee -a "$LOG"

###############################################################################
# 1) ملخص كل الخدمات (تشغيل/إيقاف/فشل)
###############################################################################
sec "All services - runtime state (systemctl list-units --all)"
systemctl list-units --type=service --all --no-pager | tee -a "$LOG"

sec "All services - unit files (systemctl list-unit-files)"
systemctl list-unit-files --type=service --no-pager | tee -a "$LOG"

###############################################################################
# 2) تفاصيل كل خدمة + تتبع المسارات
###############################################################################
sec "Per-service deep info (status + paths + Exec commands)"

# قائمة الخدمات من systemd
mapfile -t SERVICES < <(
  systemctl list-unit-files --type=service --no-legend 2>/dev/null \
    | awk '{print $1}' | sort -u
)

for svc in "${SERVICES[@]}"; do
  [ -z "$svc" ] && continue

  sec "SERVICE: $svc"

  # الحالة التفصيلية
  echo "--- systemctl status $svc ---"       | tee -a "$LOG"
  systemctl status "$svc" --no-pager -l 2>&1 | tee -a "$LOG" || true

  echo "--- systemctl show (core props) $svc ---" | tee -a "$LOG"
  systemctl show "$svc" \
    -p Description \
    -p FragmentPath \
    -p LoadState \
    -p ActiveState \
    -p SubState \
    -p UnitFileState \
    -p ExecStart \
    -p ExecStartPre \
    -p ExecStartPost \
    -p ExecStop \
    -p WorkingDirectory \
    -p Environment \
    --no-pager 2>/dev/null | tee -a "$LOG" || true

  # تتبع ملف الخدمة نفسه (FragmentPath)
  fragment="$(systemctl show "$svc" -p FragmentPath --value 2>/dev/null || true)"
  if [ -n "$fragment" ] && [ -f "$fragment" ]; then
    echo "--- Unit file path: $fragment ---" | tee -a "$LOG"
    ls -l "$fragment" | tee -a "$LOG" || true

    echo "--- Key lines from unit file (Exec*/WorkingDirectory) ---" | tee -a "$LOG"
    grep -E '^(ExecStart|ExecStartPre|ExecStartPost|ExecStop|WorkingDirectory|Environment)=' "$fragment" \
      2>/dev/null | tee -a "$LOG" || true
  else
    echo "Unit file not found on disk or no FragmentPath." | tee -a "$LOG"
  fi

  # استخراج كل المسارات التنفيذية من Exec*
  echo "--- Executable paths referenced by $svc ---" | tee -a "$LOG"
  systemctl show "$svc" \
    -p ExecStart -p ExecStartPre -p ExecStartPost -p ExecStop \
    --value 2>/dev/null \
    | tr ' ' '\n' \
    | grep '^/' | sort -u | while read -r path; do
        [ -z "$path" ] && continue
        if [ -e "$path" ]; then
          echo "[OK ] $path" | tee -a "$LOG"
          ls -ld "$path" | tee -a "$LOG" || true
        else
          echo "[MISS] $path (file not found)" | tee -a "$LOG"
        fi
      done

done

sec "Summary note"
log "Full services audit saved to: $LOG"

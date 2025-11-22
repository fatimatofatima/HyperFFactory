#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE="/opt/BRAIN_CORE"
TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_audit"
LOG="${OUT_DIR}/legacy_BRAIN_CORE_${TS}.log"

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

sec "Key subdirs (analysis/backups/communication/control/logs/memory)"
for d in analysis backups communication control logs memory; do
  if [ -e "$BASE/$d" ]; then
    ls -ld "$BASE/$d" | tee -a "$LOG"
  else
    log "MISSING: $BASE/$d"
  fi
done

sec "SQLite / DB files"
find "$BASE" -maxdepth 6 \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) \
  -printf '%p %kK\n' 2>/dev/null | tee -a "$LOG" || true

sec "Backup archives (*.tar.gz)"
ls -l "$BASE"/backups/*.tar.gz 2>/dev/null | tee -a "$LOG" || log "No backups in $BASE/backups"

sec "Virtualenvs"
find "$BASE" -maxdepth 6 -type d -name "venv" 2>/dev/null | tee -a "$LOG" || true

sec "Python entrypoints (if __name__ == '__main__')"
grep -RIl --include="*.py" -E "if __name__ ?== ?[\"']__main__[\"']" "$BASE" 2>/dev/null \
  | tee -a "$LOG" || true

sec "References to /opt/BRAIN_CORE in systemd"
grep -RIn "/opt/BRAIN_CORE" /etc/systemd 2>/dev/null | tee -a "$LOG" || true

sec "References to /opt/BRAIN_CORE in /opt projects"
grep -RIn "/opt/BRAIN_CORE" /opt 2>/dev/null | tee -a "$LOG" || true

sec "Cron references"
( crontab -l 2>/dev/null || true
  grep -RIn "/opt/BRAIN_CORE" /etc/cron* 2>/dev/null || true ) | tee -a "$LOG"

sec "Summary (read-only)"
log "1) هذا الفحص قراءة فقط، لا يوجد أي تعديل أو حذف."
log "2) لو لم يظهر أي systemd/cron يستخدم /opt/BRAIN_CORE فالمجلد مرشح للأرشفة أو الحذف بعد أخذ نسخة."
log "3) لو ظهرت وحدات systemd/خدمات تعتمد عليه، نستخدم سكربت إصلاح المراجع أو نعدّلها يدويًا."
log "تقرير الفحص: $LOG"

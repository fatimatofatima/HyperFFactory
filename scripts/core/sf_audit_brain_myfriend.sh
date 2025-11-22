#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

TS="$(date '+%Y%m%d_%H%M%S')"
OUT_DIR="/root/sf_reports"
LOG="${OUT_DIR}/sf_audit_BRAIN_CORE_MyFriend_${TS}.log"

mkdir -p "$OUT_DIR"

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

TARGETS=("BRAIN_CORE" "MyFriend")

log "=== Deep Audit: /opt/BRAIN_CORE + /opt/MyFriend (code + effects) ==="
log

for name in "${TARGETS[@]}"; do
  BASE="/opt/${name}"
  log "------------------------------------------------------------"
  log "TARGET: ${BASE}"
  if [ ! -d "$BASE" ]; then
    log "  -> MISSING (directory not found), skipping."
    continue
  fi

  du -sh "$BASE" 2>/dev/null | sed 's/^/SIZE: /' | tee -a "$LOG" || true
  stat -c 'MTIME: %y' "$BASE" 2>/dev/null | tee -a "$LOG" || true
  ls -ld "$BASE" | tee -a "$LOG"

  log
  log "1) Top-level layout (tree -L 2)"
  (cd "$BASE" && tree -L 2 2>/dev/null || find "$BASE" -maxdepth 2 -mindepth 1 -printf '%p\n') | tee -a "$LOG"

  log
  log "2) Key files (requirements / env / docker / db / services)"
  find "$BASE" -maxdepth 4 -type f \( \
      -name 'requirements*.txt' -o \
      -name 'pyproject.toml' -o \
      -name 'Pipfile*' -o \
      -name 'Dockerfile*' -o \
      -name '*.service' -o \
      -name '*.env' -o \
      -name '*.ini' -o \
      -name '*.yaml' -o \
      -name '*.yml' -o \
      -name '*.db' \
    \) 2>/dev/null | sort | tee -a "$LOG" || true

  log
  log "3) Code stats (.py / .sh) and possible entrypoints"
  PY_COUNT=$(find "$BASE" -type f -name '*.py' 2>/dev/null | wc -l || echo 0)
  SH_COUNT=$(find "$BASE" -type f -name '*.sh' 2>/dev/null | wc -l || echo 0)
  echo "   FILES: ${PY_COUNT}x .py, ${SH_COUNT}x .sh" | tee -a "$LOG"

  log "   Potential main/entry .py files:"
  find "$BASE" -type f \( -name 'main.py' -o -name 'app.py' -o -name 'api.py' -o -name '*gateway*.py' \) \
      -printf '     %p\n' 2>/dev/null | tee -a "$LOG" || true

  log
  log "4) Grep for smartfriend/smartfrind/BRAIN_CORE/MyFriend inside code (first 200 matches max)"
  grep -RIn --binary-files=without-match -E 'smartfriend|smartfrind|BRAIN_CORE|MyFriend' "$BASE" 2>/dev/null \
      | head -n 200 | tee -a "$LOG" || echo "   (no matches or grep error)" | tee -a "$LOG"

  log
  log "5) Systemd units referencing this tree (by path or name)"
  SYSTEMD_DIRS="/etc/systemd/system /lib/systemd/system"
  grep -RIl --exclude-dir='*.wants' --exclude='*.bak*' "$BASE" $SYSTEMD_DIRS 2>/dev/null \
      | sort | tee -a "$LOG" || echo "   (no direct path references)" | tee -a "$LOG"

  # أيضاً البحث بالاسم فقط
  grep -RIl --exclude-dir='*.wants' --exclude='*.bak*' -i "$name" $SYSTEMD_DIRS 2>/dev/null \
      | sort | tee -a "$LOG" || echo "   (no name-based unit matches)" | tee -a "$LOG"

  log
  log "6) Cron references (crontab + /etc/cron.d + /etc/crontab)"
  ( crontab -l 2>/dev/null || true
    cat /etc/crontab 2>/dev/null || true
    cat /etc/cron.d/* 2>/dev/null || true ) \
    | grep -i "$name" 2>/dev/null | tee -a "$LOG" || echo "   (no cron hits)" | tee -a "$LOG"

  log
  log "7) Running processes mentioning this target"
  ps aux | egrep -i "$name|$BASE" | egrep -v 'egrep|sf_audit_brain_myfriend' \
      || echo "   (no running processes found)" | tee -a "$LOG"

  log
  log "8) Quick sockets/ports snapshot (filtered by name if possible)"
  ss -ltnp 2>/dev/null | egrep -i "$name" || echo "   (no direct name in ss output; manual correlation may be needed)" | tee -a "$LOG"

  log
  log "=== End of section for ${BASE} ==="
  log
done

log "------------------------------------------------------------"
log "SUMMARY / NEXT BUSINESS STEPS:"
log " - راجع هذا التقرير لتحديد:"
log "   * هل يوجد كود أو خدمات في BRAIN_CORE / MyFriend مختلفة عن السويت الموحد."
log "   * ما هي وحدات systemd والـ cron والعمليات المرتبطة بكل مجلد."
log " - بعد المراجعة اليدوية يمكننا:"
log "   * إما دمج الوحدات / الكود في smartfriend-suite."
log "   * أو أرشفة / حذف BRAIN_CORE و MyFriend بعد تأكد 100٪ من عدم وجود اعتماد عليها."
log " - السكربت فحص فقط؛ لا يوقف خدمات ولا يحذف ملفات."
log "LOG file: $LOG"
log "=== END OF AUDIT (BRAIN_CORE + MyFriend) ==="

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BASE="/opt/smartfriend-suite/var/db"
ACTIVE="${BASE}/active_memory.db"
TS="$(date +%Y%m%d_%H%M%S)"

log(){ echo "[$(date '+%F %T')] $*"; }

log "===== SmartFriend Memory Binding → active_memory.db ====="
log "BASE  = ${BASE}"
log "ACTIVE= ${ACTIVE}"

if [ ! -f "${ACTIVE}" ]; then
  log "ERROR: active_memory.db غير موجود. أوقف التنفيذ."
  exit 1
fi

log "[1] ضبط صلاحيات active_memory.db للـ smartfrind"
chown smartfrind:smartfrind "${ACTIVE}"
chmod 640 "${ACTIVE}"
ls -l "${ACTIVE}"

# دالة مساعدة لتحويل قاعدة قديمة إلى symlink على active_memory.db
bind_db(){
  local name="$1"
  local path="${BASE}/${name}"

  log ""
  log "---- معالجة ${name} ----"
  if [ -L "${path}" ]; then
    log "INFO: ${name} هو symlink بالفعل، نعرضه فقط:"
    ls -l "${path}"
    return 0
  fi

  if [ -f "${path}" ]; then
    local backup="${path}.legacy_${TS}"
    log "نسخ احتياطي لقاعدة ${name} إلى: ${backup}"
    cp -a "${path}" "${backup}"
    log "تحويل ${name} إلى symlink يشير إلى active_memory.db"
    rm -f "${path}"
    ln -s "${ACTIVE}" "${path}"
  else
    log "لم يتم العثور على ${name} (لا ملف ولا symlink). إنشاء symlink جديد."
    ln -s "${ACTIVE}" "${path}"
  fi

  ls -l "${path}"
}

log "[2] ربط قواعد الذاكرة الصغيرة بـ active_memory.db"
bind_db "memory.db"
bind_db "smart_core_memory.db"

log ""
log "[3] إعادة تحميل systemd وتشغيل خدمات الذاكرة/الموحّد"
systemctl daemon-reload

# sf-memory: واجهة الذاكرة
if systemctl list-unit-files | grep -q '^sf-memory.service'; then
  log "إعادة تشغيل sf-memory.service ..."
  systemctl restart sf-memory.service
  systemctl status sf-memory.service --no-pager -l | head -n 20 || true
else
  log "تحذير: sf-memory.service غير موجودة في list-unit-files"
fi

# sf-unified: البوابة الموحدة (تربط الـ memory بالكوربس)
if systemctl list-unit-files | grep -q '^sf-unified.service'; then
  log "إعادة تشغيل sf-unified.service ..."
  systemctl restart sf-unified.service
  systemctl status sf-unified.service --no-pager -l | head -n 20 || true
else
  log "تحذير: sf-unified.service غير موجودة في list-unit-files"
fi

log ""
log "[4] فحص Health بعد الربط"

if command -v curl >/dev/null 2>&1; then
  log "GET sf-memory /health"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8214/health || true

  log "GET sf-unified /health"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" http://127.0.0.1:8220/health || true
else
  log "curl غير موجود؛ تخطي فحص HTTP health."
fi

log ""
log "===== DONE: Memory bound to active_memory.db عبر symlinks ====="

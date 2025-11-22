#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

UNIT="/etc/systemd/system/sf-memory.service"
BACKUP_DIR="/root/unit_backups_$(date +%Y%m%d_%H%M%S)"

log "ربط sf-memory مع active_memory.db"
log "UNIT = ${UNIT}"

if [ ! -f "$UNIT" ]; then
  log "ERROR: ملف خدمة sf-memory غير موجود: $UNIT"
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cp -a "$UNIT" "${BACKUP_DIR}/" 
log "✅ تم نسخ الوحدة احتياطيًا إلى: ${BACKUP_DIR}/"

log "فحص وجود أي إشارة إلى memory.db داخل الوحدة..."
if grep -q "memory.db" "$UNIT"; then
  log "تم العثور على memory.db داخل الوحدة – تنفيذ الاستبدال إلى active_memory.db"
  sed -i 's|/var/db/memory.db|/var/db/active_memory.db|g' "$UNIT" || true
  sed -i 's|memory.db|active_memory.db|g' "$UNIT" || true
  CHANGED=1
else
  log "⚠ لا توجد إشارة صريحة لـ memory.db داخل الوحدة. لم يتم تعديل ExecStart."
  CHANGED=0
fi

log "إعادة تحميل systemd..."
systemctl daemon-reload

log "إعادة تشغيل sf-memory..."
systemctl restart sf-memory.service || {
  log "ERROR: فشل إعادة تشغيل sf-memory.service – راجع journalctl -u sf-memory.service"
  exit 1
}

log "حالة الخدمة بعد التعديل:"
systemctl status sf-memory.service --no-pager --lines=5 || true

log "تشغيل فحص health للـ BrainStack (إن وجد)..."
if [ -x /root/sf_brainstack_health.sh ]; then
  /root/sf_brainstack_health.sh || true
else
  log "ملاحظة: /root/sf_brainstack_health.sh غير موجود أو غير قابل للتنفيذ."
fi

log "انتهى ربط sf-memory مع active_memory.db (CHANGED=${CHANGED})"

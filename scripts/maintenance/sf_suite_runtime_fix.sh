#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log()   { echo "[$(date '+%F %T')] $*"; }
warn()  { echo "[$(date '+%F %T')] [WARN] $*" >&2; }
error() { echo "[$(date '+%F %T')] [ERROR] $*" >&2; }

SFDIR="/opt/smartfriend-suite/smartfriend"
VENV_DIR="$SFDIR/venv"
VENV_PY="$VENV_DIR/bin/python"

log "1) فحص مسار SmartFriend Suite"
if [ ! -d "$SFDIR" ]; then
    error "المسار $SFDIR غير موجود – تأكد إن هذا هو مسار السويت الأساسي."
    exit 1
fi

log "2) إنشاء مجلدات logs/data لـ SmartFriend إن لم تكن موجودة"
mkdir -p \
  "$SFDIR/logs" \
  "$SFDIR/data" \
  /var/log/smartfrind \
  /var/log/smartfriend

# لو فيه يوزر مخصص اسمه smartfrind نضبط الملكية
if id smartfrind >/dev/null 2>&1; then
  chown -R smartfrind:smartfrind "$SFDIR/logs" "$SFDIR/data" /var/log/smartfrind || true
else
  log "يوزر smartfrind غير موجود أو غير معرف – نترك الملكية الافتراضية."
fi

log "3) فحص venv وصلاحيات python"
if [ ! -x "$VENV_PY" ]; then
  if [ -f "$VENV_PY" ]; then
    warn "ملف venv python موجود لكن غير قابل للتنفيذ – سيتم ضبط الصلاحيات."
    chmod 750 "$VENV_PY" || warn "فشل تعديل صلاحيات $VENV_PY"
    chmod 750 "$VENV_DIR/bin/"* || true
  else
    error "لم يتم العثور على $VENV_PY – تأكد من أن الـ venv تم إنشاؤه في $VENV_DIR"
  fi
else
  log "صلاحيات venv/bin/python تبدو سليمة."
fi

log "4) قائمة مختصرة بخدمات SmartFriend (بدون ffactory)"
systemctl list-unit-files | grep -E '^(sf-|smartfrind-|smartfriend-).*\.service' || true

log "5) إعادة تشغيل خدمات SmartFriend الأساسية إن وجدت"
SERVICES=(
  sf-web.service
  smartfrind-core.service
  smartfrind-qa.service
  smartfrind-ai-gateway.service
  smartfrind-advanced.service
  smartfrind-local.service
  sf-telegram.service
  sf-backup.service
  sf-db-backup.service
  smartfrind-backup.service
  smartfrind-learner.service
  smartfrind-learning-agent.service
)

for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}"; then
    log "إعادة تشغيل الخدمة: $svc"
    if systemctl restart "$svc"; then
      log "✅ تم إعادة تشغيل $svc"
    else
      warn "⚠ فشل في إعادة تشغيل $svc – سيتم عرض آخر 10 أسطر من اللوج"
      journalctl -u "$svc" -n 10 --no-pager || true
    fi
  fi
done

log "6) ملخص حالة الخدمات بعد الإصلاح"
systemctl --no-pager --type=service | grep -E '^(sf-|smartfrind-|smartfriend-)' || true

log "تم تنفيذ إصلاح البنية الأساسية لـ SmartFriend Suite (بدون لمس ffactory)."

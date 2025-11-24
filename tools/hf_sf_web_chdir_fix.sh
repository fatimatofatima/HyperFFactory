#!/usr/bin/env bash
# HyperFFactory – Fix sf-web CHDIR (WorkingDirectory + perms)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
WEB_DIR="$SUITE_ROOT/web"
UNIT="sf-web.service"

REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_chdir_fix_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "SmartFriend – Fix sf-web CHDIR (WorkingDirectory + perms)"
log "SUITE_ROOT : $SUITE_ROOT"
log "WEB_DIR    : $WEB_DIR"
log "UNIT       : $UNIT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

log "=== 1) Pre-status snapshot (sf-web) ==="
systemctl status "$UNIT" --no-pager -l 2>&1 | tee -a "$LOG" || true

log "=== 2) فحص صلاحيات المسارات /opt → smartfriend-suite → web ==="
{
  echo "---- ls -ld ----"
  ls -ld /opt "$SUITE_ROOT" "$WEB_DIR" 2>&1 || echo "⚠️ بعض المسارات غير موجودة"
  echo
  echo "---- namei -om $WEB_DIR ----"
  namei -om "$WEB_DIR" 2>&1 || echo "⚠️ namei فشل – ربما المجلد غير موجود"
} | tee -a "$LOG"

log "=== 3) ضمان وجود مجلد الويب ==="
if [ ! -d "$SUITE_ROOT" ]; then
  log "❌ SUITE_ROOT غير موجود: $SUITE_ROOT – لن أنشئه تلقائيًا. تحقق من تثبيت السيوت."
  exit 1
fi

if [ ! -d "$WEB_DIR" ]; then
  log "⚠️ مجلد الويب غير موجود – إنشاؤه: $WEB_DIR"
  mkdir -p "$WEB_DIR"
fi

log "=== 4) ضبط صلاحيات المسارات (755 للمرور) ==="
{
  echo "قبل التعديل:"
  ls -ld /opt "$SUITE_ROOT" "$WEB_DIR" 2>&1 || true
} | tee -a "$LOG"

chmod 755 /opt "$SUITE_ROOT" "$WEB_DIR" || log "⚠️ فشل chmod على بعض المسارات (استمر)"

{
  echo "بعد التعديل:"
  ls -ld /opt "$SUITE_ROOT" "$WEB_DIR" 2>&1 || true
} | tee -a "$LOG"

log "=== 5) كتابة drop-in نهائي 80-hf-web-final.conf ==="
DROPIN_DIR="/etc/systemd/system/$UNIT.d"
mkdir -p "$DROPIN_DIR"

DROPIN_FILE="$DROPIN_DIR/80-hf-web-final.conf"

cat > "$DROPIN_FILE" <<'EOC'
[Service]
# تأكيد مسار العمل للويب
WorkingDirectory=/opt/smartfriend-suite/web

# إعادة تعريف ExecStart بالكامل (سطر فارغ أولاً لتصفير القديم)
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
EOC

log "✓ كتبنا $DROPIN_FILE بالمحتوى النهائي"

log "=== 6) systemd daemon-reload + restart sf-web ==="
log "▶️ systemctl daemon-reload"
systemctl daemon-reload

log "▶️ إعادة تشغيل sf-web.service"
if systemctl restart "$UNIT"; then
  log "✓ sf-web.service أعيد تشغيله (restart أمر)"
else
  log "⚠️ فشل في إعادة تشغيل sf-web.service (restart أمر)"
fi

log "=== 7) Post-status snapshot (sf-web) ==="
systemctl status "$UNIT" --no-pager -l 2>&1 | tee -a "$LOG" || true

log "=== 8) Health check على 8390 (إن أمكن) ==="
{
  echo "---- curl 8390 /health ----"
  curl -sS http://127.0.0.1:8390/health 2>&1 || echo "❌ /health غير متاح"
  echo
  echo "---- curl 8390 / ----"
  curl -sS http://127.0.0.1:8390/ 2>&1 || echo "❌ / غير متاح"
} | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_web_chdir_fix finished"
log "Report: $LOG"
log "====================================================="

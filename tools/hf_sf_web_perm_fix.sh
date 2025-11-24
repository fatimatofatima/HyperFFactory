#!/usr/bin/env bash
# HyperFFactory – Fix sf-web CHDIR by moving WorkingDirectory out of /root

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
BACKUP_DIR="$ROOT/backup_systemd_dropins"
DROPIN_DIR="/etc/systemd/system/sf-web.service.d"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$DROPIN_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_perm_fix_${TS}.log"

log() { echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "====================================================="
log "HyperFFactory – sf-web WORKDIR/PERM fix"
log "SUITE_ROOT : $SUITE_ROOT"
log "DROPIN_DIR : $DROPIN_DIR"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

log "1) التأكد من مجلد الويب /opt/smartfriend-suite/web وملف run_web.py"

WEB_DIR="$SUITE_ROOT/web"
WEB_FILE="$WEB_DIR/run_web.py"

if [ ! -d "$WEB_DIR" ]; then
  log "⚠️ $WEB_DIR غير موجود – إنشاؤه الآن"
  mkdir -p "$WEB_DIR"
fi

if [ -f "$WEB_FILE" ]; then
  log "✓ وجدنا $WEB_FILE"
else
  log "⚠️ لم نجد $WEB_FILE – الخدمة ستحتاج هذا الملف لتعمل"
fi

# ضبط الملكية والصلاحيات بحيث يقدر smartfriend-suite يدخل ويشغّل
if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite "$WEB_DIR" || true
  log "✓ عدّلنا ملكية $WEB_DIR إلى smartfriend-suite:smartfriend-suite"
else
  log "ℹ️ مستخدم smartfriend-suite غير موجود – تخطي تغيير الملكية"
fi

# السماح بالوصول للمسار (execute bit) بدون فتح الكتابة للجميع
chmod 755 /opt || true
chmod 755 "$SUITE_ROOT" || true
chmod 755 "$WEB_DIR" || true
log "✓ عدّلنا صلاحيات /opt, $SUITE_ROOT, $WEB_DIR إلى 755 (دخول فقط)"

log "2) backup لـ override.conf القديم (بدون حذف)"

OVERRIDE_SRC="$DROPIN_DIR/override.conf"
if [ -f "$OVERRIDE_SRC" ]; then
  BAK="$BACKUP_DIR/sf-web.override.conf_${TS}.bak"
  cp -a "$OVERRIDE_SRC" "$BAK"
  log "✓ أخذنا نسخة احتياطية من override.conf إلى $BAK"
else
  log "ℹ️ لا يوجد override.conf حالي – سننشئ واحد جديد"
fi

log "3) كتابة override.conf جديد بأولوية نهائية (يلغي المسارات تحت /root)"

cat > "$OVERRIDE_SRC" <<CONF
[Service]
# نقل الـ WorkingDirectory من /root/... إلى مسار آمن تحت /opt
WorkingDirectory=/opt/smartfriend-suite/web
Environment=PYTHONPATH=/opt/smartfriend-suite

# إعادة تعريف ExecStart بالكامل إلى مسار ثابت
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF

log "✓ كتبنا $OVERRIDE_SRC بالقيم الجديدة"

log "4) daemon-reload + restart sf-web"

systemctl daemon-reload

if systemctl restart sf-web.service; then
  log "✓ sf-web.service تم إعادة تشغيله بنجاح"
else
  log "⚠️ فشل في إعادة تشغيل sf-web.service – راجع status بالأسفل"
fi

log "5) systemctl status sf-web (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

log "6) اختبار /health على 8390"
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI غير متاح"

log "====================================================="
log "DONE – hf_sf_web_perm_fix"
log "Report: $LOG"
log "====================================================="

#!/usr/bin/env bash
# HyperFFactory – Fix sf-web Python import path (apps.web)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
DROPIN_DIR="/etc/systemd/system/sf-web.service.d"

mkdir -p "$REPORT_DIR" "$DROPIN_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_py_path_fix_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – sf-web PYTHONPATH fix"
log "SUITE_ROOT : $SUITE_ROOT"
log "DROPIN_DIR : $DROPIN_DIR"
log "TIME       : $TS"
log "LOG        : $LOG"
log "=================================================="

APP_FILE="$SUITE_ROOT/apps/web/app.py"
if [[ -f "$APP_FILE" ]]; then
  log "✓ وجدنا ملف التطبيق: $APP_FILE"
else
  log "⚠️ لم نجد $APP_FILE – سنضبط PYTHONPATH على أي حال (قد يختلف المسار في هذا الإصدار)."
fi

# 1) كتابة Drop-in جديد لتهيئة PYTHONPATH
log "1) كتابة 95-hf-web-pythonpath.conf لضبط PYTHONPATH"

cat > "$DROPIN_DIR/95-hf-web-pythonpath.conf" <<'EOF_CONF'
[Service]
# إضافة مسارات المشروع إلى PYTHONPATH قبل تشغيل run_web.py
Environment="PYTHONPATH=/opt/smartfriend-suite:/opt/smartfriend-suite/web:$PYTHONPATH"
EOF_CONF

log "✓ كتبنا $DROPIN_DIR/95-hf-web-pythonpath.conf"

# 2) daemon-reload + restart sf-web
log "2) systemctl daemon-reload + restart sf-web.service"
systemctl daemon-reload

if systemctl restart sf-web.service; then
  log "✓ sf-web.service تم إعادة تشغيله (restart) بنجاح (من حيث systemd)"
else
  log "⚠️ فشل في إعادة تشغيل sf-web.service – تابع رسالة status أدناه"
fi

# 3) عرض أول 40 سطر من حالة الخدمة
log "3) systemctl status sf-web (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG"

# 4) اختبار /health على 8390 (إن اشتغلت)
log "4) اختبار Web UI على 8390 (/health, /)"
{
  curl -s http://127.0.0.1:8390/health || echo "❌ Web UI /health غير متاح"
  curl -s http://127.0.0.1:8390/       || echo "❌ Web UI / غير متاح"
} | tee -a "$LOG"

log "=================================================="
log "DONE – hf_sf_web_py_path_fix"
log "Report: $LOG"
log "=================================================="

#!/usr/bin/env bash
# HyperFFactory – Fix sf-web CHDIR by allowing traverse into /root for smartfriend-suite

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_root_traverse_fix_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – sf-web CHDIR root traverse fix"
log "ROOT        : $ROOT"
log "TIME        : $TS"
log "LOG         : $LOG"
log "====================================================="

log "1) حالة المسارات قبل التعديل"
{
  echo "---- namei -om /opt/smartfriend-suite/web ----"
  namei -om /opt/smartfriend-suite/web || true
  echo
  echo "---- ls -ld /root /root/HyperFFactory /root/HyperFFactory/opt /root/HyperFFactory/opt/smartfriend-suite /root/HyperFFactory/opt/smartfriend-suite/web ----"
  ls -ld /root /root/HyperFFactory /root/HyperFFactory/opt /root/HyperFFactory/opt/smartfriend-suite /root/HyperFFactory/opt/smartfriend-suite/web 2>/dev/null || true
} | tee -a "$LOG"

log "2) تعديل صلاحيات /root للسماح بالـ traverse (x فقط للآخرين)"
# نرفع صلاحيات /root إلى 711 (rwx------ → rwx--x--x)، مع الحفاظ على سريّة المحتوى
chmod 711 /root
log "✓ تم تعديل صلاحيات /root إلى 711"

log "3) ضمان أن مسار HyperFFactory وما تحته world-executable (755)"
chmod 755 /root/HyperFFactory || true
chmod 755 /root/HyperFFactory/opt || true
chmod 755 /root/HyperFFactory/opt/smartfriend-suite || true
chmod 755 /root/HyperFFactory/opt/smartfriend-suite/web || true
log "✓ تم ضبط 755 على HyperFFactory/opt/smartfriend-suite/web"

log "4) حالة المسارات بعد التعديل"
{
  echo "---- namei -om /opt/smartfriend-suite/web (بعد) ----"
  namei -om /opt/smartfriend-suite/web || true
  echo
  echo "---- ls -ld /root /root/HyperFFactory /root/HyperFFactory/opt /root/HyperFFactory/opt/smartfriend-suite /root/HyperFFactory/opt/smartfriend-suite/web (بعد) ----"
  ls -ld /root /root/HyperFFactory /root/HyperFFactory/opt /root/HyperFFactory/opt/smartfriend-suite /root/HyperFFactory/opt/smartfriend-suite/web 2>/dev/null || true
} | tee -a "$LOG"

log "5) daemon-reload + restart sf-web.service"
systemctl daemon-reload || log "⚠ systemctl daemon-reload فشل (تجاهلنا الخطأ)"
if systemctl restart sf-web.service; then
  log "✓ تم تنفيذ systemctl restart sf-web.service"
else
  log "⚠ فشل في restart sf-web.service"
fi

log "6) systemctl status sf-web (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

log "7) فحص /health على 8390 (إن اشتغل)"
{
  echo "---- curl /health ----"
  curl -s http://127.0.0.1:8390/health || echo \"❌ Web UI /health غير متاح\"
  echo
  echo "---- curl / ----"
  curl -s http://127.0.0.1:8390/       || echo \"❌ Web UI / غير متاح\"
} | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_sf_web_root_traverse_fix"
log "Report: $LOG"
log "====================================================="

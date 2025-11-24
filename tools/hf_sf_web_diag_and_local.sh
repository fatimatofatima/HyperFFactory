#!/usr/bin/env bash
# HyperFFactory – sf-web diagnostic & local run
# - يلتزم بسياسة الهيكل الموحّد:
#   * التنفيذ من /root/HyperFFactory
#   * لمس /opt/smartfriend-suite فقط كنقطة تكامل
# - يجمع:
#   * محتوى app.py و run_web.py
#   * فحص compile
#   * تجربة تشغيل محلي لـ run_web.py
#   * journalctl -u sf-web.service

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_diag_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – sf-web diagnostic & local run"
log "Time : $TS"
log "Root : $ROOT"
log "Suite: $SUITE_ROOT"
log "Log  : $LOG"
log "=================================================="

APP_DIR="$SUITE_ROOT/apps/web"
WEB_DIR="$SUITE_ROOT/web"

########################################
# 1) عرض ملخص الملفات
########################################
log "1) فحص وجود ملفات sf-web الأساسية"

if [[ -f "$APP_DIR/app.py" ]]; then
  log "✓ موجود: $APP_DIR/app.py"
else
  log "❌ مفقود: $APP_DIR/app.py"
fi

if [[ -f "$WEB_DIR/run_web.py" ]]; then
  log "✓ موجود: $WEB_DIR/run_web.py"
else
  log "❌ مفقود: $WEB_DIR/run_web.py"
fi

log "---- head apps/web/app.py ----"
[[ -f "$APP_DIR/app.py" ]] && head -n 40 "$APP_DIR/app.py" | sed 's/^/APP: /' | tee -a "$LOG" || true

log "---- head web/run_web.py ----"
[[ -f "$WEB_DIR/run_web.py" ]] && head -n 40 "$WEB_DIR/run_web.py" | sed 's/^/RUN: /' | tee -a "$LOG" || true

########################################
# 2) فحص compile للكود
########################################
log "2) Python compile check لـ apps/web و web/"

if command -v python3 >/dev/null 2>&1; then
  (
    cd "$SUITE_ROOT"
    python3 -m compileall -q apps/web web
  ) && log "✓ compileall نجح" || log "❌ compileall فشل (راجع الرسائل أعلاه إن وجدت)"
else
  log "❌ python3 غير موجود في PATH"
fi

########################################
# 3) تجربة استيراد app من نفس بيئة systemd تقريباً
########################################
log "3) تجربة استيراد apps.web.app:app مع PYTHONPATH مناسب"

PYTHONPATH="$SUITE_ROOT:$SUITE_ROOT/apps" \
python3 - <<'PYEOF' 2>&1 | sed 's/^/IMPORT: /' | tee -a "$LOG" || true
import sys
print("sys.path[0:5] =", sys.path[:5])
try:
    from apps.web.app import app
    import fastapi
    import uvicorn
    print("✅ Import OK – FastAPI app موجود:", type(app))
except Exception as e:
    import traceback
    print("❌ Import failed:", e)
    traceback.print_exc()
PYEOF

########################################
# 4) إيقاف الخدمة وتجربة تشغيل run_web.py محليًا مع timeout
########################################
log "4) إيقاف sf-web.service مؤقتًا وتجربة تشغيل run_web.py محليًا"

if systemctl list-unit-files sf-web.service >/dev/null 2>&1; then
  systemctl stop sf-web.service || log "⚠️ تحذير: فشل إيقاف sf-web.service (ممكن تكون متوقفة أصلًا)"
else
  log "ℹ️ sf-web.service غير معرّفة كوحدة systemd (تخطي الإيقاف)"
fi

if [[ -f "$WEB_DIR/run_web.py" ]]; then
  log "تشغيل run_web.py لمدة 5 ثواني مع timeout (PYTHONPATH مضبوط)"
  if command -v timeout >/dev/null 2>&1; then
    (
      cd "$SUITE_ROOT"
      PYTHONPATH="$SUITE_ROOT:$SUITE_ROOT/apps" \
      timeout 5 python3 web/run_web.py
    ) >>"$LOG" 2>&1 || log "ℹ️ run_web.py انتهى قبل 5 ثواني (إما خروج طبيعي أو خطأ – راجع اللوج)"
  else
    log "⚠️ timeout غير متاح – سيتم تشغيل run_web.py مرة واحدة بدون حد زمني (قد يتوقف عند CTRL+C فقط)"
    (
      cd "$SUITE_ROOT"
      PYTHONPATH="$SUITE_ROOT:$SUITE_ROOT/apps" \
      python3 web/run_web.py
    ) >>"$LOG" 2>&1 || log "ℹ️ run_web.py خرج بخطأ – راجع اللوج"
  fi
else
  log "❌ run_web.py غير موجود – لا يمكن تشغيله محليًا"
fi

########################################
# 5) إعادة تشغيل الخدمة وسحب journalctl
########################################
log "5) إعادة تشغيل sf-web.service وسحب آخر لاجات من journalctl"

if systemctl list-unit-files sf-web.service >/dev/null 2>&1; then
  if systemctl restart sf-web.service; then
    log "✓ sf-web.service تم إعادة تشغيله (systemd)"
  else
    log "❌ فشل restart sf-web.service"
  fi

  sleep 2

  log "---- systemctl status sf-web.service (أول 40 سطر) ----"
  systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

  log "---- journalctl -u sf-web.service -n 50 ----"
  journalctl -u sf-web.service -n 50 --no-pager | tee -a "$LOG" || true
else
  log "ℹ️ sf-web.service غير معرّفة – تخطي جزء systemd"
fi

log "=================================================="
log "DONE – hf_sf_web_diag_and_local"
log "Report: $LOG"
log "=================================================="

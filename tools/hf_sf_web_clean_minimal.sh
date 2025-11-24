#!/usr/bin/env bash
# HyperFFactory – تنظيف وإعادة بناء sf-web (SmartFriend Web UI)
# - يلتزم بسياسة الهيكل الموحّد:
#   * التنفيذ من /root/HyperFFactory
#   * لمس /opt/smartfriend-suite فقط كنقطة تكامل
# - يعيد بناء:
#   * /opt/smartfriend-suite/apps/web/__init__.py
#   * /opt/smartfriend-suite/apps/web/app.py
#   * /opt/smartfriend-suite/web/run_web.py
# - ثم:
#   * python3 -m compileall
#   * restart sf-web.service
#   * اختبار /health و /

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_clean_minimal_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – sf-web clean & rebuild (minimal)"
log "Time : $TS"
log "Root : $ROOT"
log "Suite: $SUITE_ROOT"
log "Log  : $LOG"
log "=================================================="

APP_DIR="$SUITE_ROOT/apps/web"
WEB_DIR="$SUITE_ROOT/web"

mkdir -p "$APP_DIR" "$WEB_DIR"

########################################
# 1) __init__.py
########################################
log "1) كتابة apps/web/__init__.py نظيف"

cat > "$APP_DIR/__init__.py" <<'PYEOF'
"""
SmartFriend Suite - Web package

حزمة واجهة الويب الخاصة بـ SmartFriend Suite.
يمكن توسيعها لاحقاً بإضافة submodules مثل:
- dashboards
- views
- api_v1
"""
PYEOF

########################################
# 2) app.py – FastAPI بسيط وصحيح
########################################
log "2) كتابة apps/web/app.py (FastAPI minimal app)"

cat > "$APP_DIR/app.py" <<'PYEOF'
from datetime import datetime

from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Web UI",
    version="0.1.0",
    description="Minimal SmartFriend Web UI placeholder.",
)


@app.get("/health")
async def health():
    """
    نقطة صحّة بسيطة لخدمة sf-web.
    ترجع حالة OK مع التوقيت الحالي.
    """
    return {
        "status": "ok",
        "service": "sf-web",
        "time": datetime.utcnow().isoformat(),
    }


@app.get("/")
async def root():
    """
    الصفحة الرئيسية البسيطة لواجهة SmartFriend Web UI.
    يمكن توسيعها لاحقاً لتصبح لوحة تحكم كاملة.
    """
    return {
        "service": "SmartFriend Web UI",
        "version": "0.1.0",
        "message": "SmartFriend Web placeholder is running",
        "time": datetime.utcnow().isoformat(),
    }
PYEOF

########################################
# 3) run_web.py – Uvicorn launcher
########################################
log "3) كتابة web/run_web.py (Uvicorn launcher)"

cat > "$WEB_DIR/run_web.py" <<'PYEOF'
#!/usr/bin/env python3
"""
SmartFriend Web UI launcher (sf-web.service)

يقوم بالآتي:
1) إضافة /opt/smartfriend-suite و /opt/smartfriend-suite/apps إلى sys.path
2) تشغيل FastAPI app الموجود في apps.web.app:app
3) استخدام 127.0.0.1:8390 افتراضياً (يمكن تعديله من env: SF_WEB_HOST / SF_WEB_PORT)
"""

import os
import sys
from pathlib import Path

import uvicorn


def main() -> None:
    # /opt/smartfriend-suite/web -> parent = /opt/smartfriend-suite
    base_dir = Path(__file__).resolve().parent.parent
    apps_dir = base_dir / "apps"

    # تثبيت المسارات في sys.path
    if str(base_dir) not in sys.path:
        sys.path.insert(0, str(base_dir))
    if str(apps_dir) not in sys.path:
        sys.path.insert(0, str(apps_dir))

    host = os.environ.get("SF_WEB_HOST", "127.0.0.1")
    port_str = os.environ.get("SF_WEB_PORT", "8390")
    try:
        port = int(port_str)
    except ValueError:
        port = 8390

    uvicorn.run(
        "apps.web.app:app",
        host=host,
        port=port,
        reload=False,
        workers=1,
    )


if __name__ == "__main__":
    main()
PYEOF

chmod 755 "$WEB_DIR/run_web.py"

########################################
# 4) compileall للتحقق من سلامة الكود
########################################
log "4) Python compile check لـ apps/web و web/"

if command -v python3 >/dev/null 2>&1; then
  (
    cd "$SUITE_ROOT"
    python3 -m compileall -q apps/web web
  ) && log "✓ compileall نجح (لا يوجد SyntaxError)" || log "❌ compileall فشل – راجع الرسائل أعلاه"
else
  log "❌ python3 غير موجود في PATH"
fi

########################################
# 5) restart sf-web.service + status
########################################
log "5) إعادة تشغيل sf-web.service"

if systemctl list-unit-files sf-web.service >/dev/null 2>&1; then
  systemctl restart sf-web.service || log "❌ فشل restart sf-web.service"
  sleep 2
  log "---- systemctl status sf-web.service (أول 40 سطر) ----"
  systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true
else
  log "ℹ️ sf-web.service غير معرّفة كوحدة systemd"
fi

########################################
# 6) curl /health و /
########################################
log "6) اختبار HTTP على 127.0.0.1:8390 (health و root)"

if command -v curl >/dev/null 2>&1; then
  echo "---- GET /health ----" | tee -a "$LOG"
  curl -s http://127.0.0.1:8390/health | tee -a "$LOG" || echo "❌ Web UI /health غير متاح" | tee -a "$LOG"
  echo "" | tee -a "$LOG"
  echo "---- GET / ----" | tee -a "$LOG"
  curl -s http://127.0.0.1:8390/ | tee -a "$LOG" || echo "❌ Web UI / غير متاح" | tee -a "$LOG"
  echo "" | tee -a "$LOG"
else
  log "ℹ️ curl غير متاح – تخطّي اختبار HTTP اليدوي"
fi

log "=================================================="
log "DONE – hf_sf_web_clean_minimal"
log "Report: $LOG"
log "=================================================="

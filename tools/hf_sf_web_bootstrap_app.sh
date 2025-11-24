#!/usr/bin/env bash
# HyperFFactory – Bootstrap minimal SmartFriend Web UI (sf-web)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_bootstrap_app_${TS}.log"

mkdir -p "$REPORT_DIR"
mkdir -p "$SUITE_ROOT/apps/web"
mkdir -p "$SUITE_ROOT/web"

log() {
  echo "[$(date +'%F %T')] $*" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Bootstrap sf-web (FastAPI minimal UI)"
log "SUITE_ROOT : $SUITE_ROOT"
log "LOG        : $LOG"
log "====================================================="

# 1) __init__.py للباكدج apps.web
log "✓ كتابة /opt/smartfriend-suite/apps/web/__init__.py"
cat > "$SUITE_ROOT/apps/web/__init__.py" <<'PYEOF'
"""
SmartFriend Web UI package (bootstrap version).

This package exposes a minimal FastAPI application used by sf-web.service.
"""
PYEOF

# 2) app.py – تطبيق FastAPI أساسي
log "✓ كتابة /opt/smartfriend-suite/apps/web/app.py"
cat > "$SUITE_ROOT/apps/web/app.py" <<'PYEOF'
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

APP_NAME = os.environ.get("SF_WEB_APP_NAME", "SmartFriend Web UI")
APP_VERSION = os.environ.get("SF_WEB_VERSION", "0.1.0-bootstrap")

app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="Bootstrap Web UI for SmartFriend Suite (sf-web).",
)

# CORS – مفتوح الآن، يمكن تضييقه لاحقًا عند الحاجة
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health():
    """
    Health endpoint بسيط يستخدمه HyperFFactory / Nginx / أي مراقبة.
    """
    return {
        "status": "ok",
        "service": "sf-web",
        "component": "SmartFriend Web UI",
        "version": APP_VERSION,
    }


@app.get("/")
async def root():
    """
    Root endpoint بسيط يعطي رسالة ترحيب وروابط مفيدة.
    """
    return {
        "message": "SmartFriend Web UI (bootstrap)",
        "docs": "/docs",
        "health": "/health",
        "version": APP_VERSION,
    }
PYEOF

# 3) run_web.py – نقطة تشغيل sf-web.service
log "✓ كتابة /opt/smartfriend-suite/web/run_web.py"
cat > "$SUITE_ROOT/web/run_web.py" <<'PYEOF'
"""
run_web.py – نقطة تشغيل SmartFriend Web UI (sf-web.service).

يشغّل FastAPI app من apps.web.app باستخدام uvicorn.
"""

import os
import sys
from pathlib import Path

# ضبط BASE_DIR ليشير إلى جذر السيوت: /opt/smartfriend-suite
CURRENT_FILE = Path(__file__).resolve()
BASE_DIR = CURRENT_FILE.parent.parent  # /opt/smartfriend-suite

if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

try:
    from apps.web.app import app  # type: ignore  # noqa: E402
except Exception as exc:  # pragma: no cover
    # طباعة خطأ واضح في stdout/stderr ليستقبله systemd
    print("❌ فشل في استيراد apps.web.app من run_web.py:", exc, file=sys.stderr)
    raise

def main() -> None:
    import uvicorn  # يفترض وجوده في بيئة السيوت

    port = int(os.environ.get("SF_WEB_PORT", "8390"))
    host = os.environ.get("SF_WEB_HOST", "0.0.0.0")

    uvicorn.run(
        app,
        host=host,
        port=port,
        workers=int(os.environ.get("SF_WEB_WORKERS", "1")),
    )


if __name__ == "__main__":
    main()
PYEOF

# 4) ضبط الملكية (لا نكسر أي شيء موجود)
log "✓ ضبط الملكية إلى smartfriend-suite:smartfriend-suite على web/apps.web"
chown -R smartfriend-suite:smartfriend-suite "$SUITE_ROOT/apps/web" "$SUITE_ROOT/web" 2>/dev/null || true

# 5) إعادة تحميل systemd وتشغيل الخدمة
log "✓ systemctl daemon-reload"
systemctl daemon-reload

log "▶️ إعادة تشغيل sf-web.service"
if ! systemctl restart sf-web.service; then
  log "⚠️ فشل في restart sf-web.service – راجع journalctl -u sf-web.service"
fi

sleep 2

log "=== systemctl status sf-web (أول 40 سطر) ==="
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

log "=== Health check على 8390 ==="
curl -s http://127.0.0.1:8390/health 2>/dev/null || echo "❌ Web UI /health غير متاح" | tee -a "$LOG"

log "====================================================="
log "DONE – hf_sf_web_bootstrap_app finished – تقرير: $LOG"
log "====================================================="

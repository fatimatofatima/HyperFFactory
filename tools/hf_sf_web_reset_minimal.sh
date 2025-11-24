#!/usr/bin/env bash
# HyperFFactory – Reset minimal sf-web (SmartFriend Web UI)
# - يبني apps/web/app.py نظيف
# - يبني web/run_web.py نظيف
# - يعمل restart لـ sf-web.service ويفحص /health و /

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_reset_minimal_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – sf-web reset (minimal)"
log "Time : $TS"
log "SUITE: $SUITE_ROOT"
log "Log  : $LOG"
log "=================================================="

APP_DIR="$SUITE_ROOT/apps/web"
WEB_DIR="$SUITE_ROOT/web"

mkdir -p "$APP_DIR" "$WEB_DIR"

########################################
# 1) apps/web/__init__.py
########################################
log "1) كتابة apps/web/__init__.py"

cat > "$APP_DIR/__init__.py" <<'PYEOF'
"""
SmartFriend Suite - Web package (sf-web)

هذا الموديول يعرّف حزمة الويب الأساسية.
يمكن توسيعه لاحقاً لإضافة submodules أخرى (لوحة تحكم، صفحات، API إضافية...).
"""
PYEOF

########################################
# 2) apps/web/app.py  (FastAPI app)
########################################
log "2) كتابة apps/web/app.py (FastAPI Fast Health UI)"

cat > "$APP_DIR/app.py" <<'PYEOF'
from datetime import datetime
from typing import Dict, Any

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(
    title="SmartFriend Web UI",
    version="0.1.0",
    description="Minimal SmartFriend Web UI placeholder (HyperFFactory integrated).",
)


@app.get("/health")
async def health() -> Dict[str, Any]:
    """
    نقطة صحة بسيطة لخدمة sf-web.
    يمكن لاحقاً ربطها بمركز الصحة الموحّد في HyperFFactory.
    """
    return {
        "status": "ok",
        "service": "sf-web",
        "time": datetime.utcnow().isoformat() + "Z",
    }


@app.get("/", response_class=HTMLResponse)
async def index() -> str:
    """
    صفحة جذر بسيطة لواجهة الويب.
    """
    now = datetime.utcnow().isoformat() + "Z"
    html = f"""<!DOCTYPE html>
<html lang="ar">
<head>
  <meta charset="utf-8" />
  <title>SmartFriend Web UI</title>
</head>
<body>
  <h1>SmartFriend Web UI</h1>
  <p>هذه واجهة ويب مبدئية تحت إدارة HyperFFactory.</p>
  <ul>
    <li><a href="/health">/health</a> – فحص صحة الخدمة</li>
  </ul>
  <hr />
  <p>UTC time: {now}</p>
</body>
</html>
"""
    return html
PYEOF

########################################
# 3) web/run_web.py (uvicorn launcher)
########################################
log "3) كتابة web/run_web.py (uvicorn launcher)"

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
    base_dir = Path(__file__).resolve().parent.parent  # /opt/smartfriend-suite
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

    # تشغيل Uvicorn على apps.web.app:app
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

########################################
# 4) ضبط الصلاحيات
########################################
log "4) ضبط صلاحيات web/run_web.py"

chmod 755 "$WEB_DIR/run_web.py"

########################################
# 5) Restart sf-web.service
########################################
log "5) systemctl daemon-reload + restart sf-web.service"

systemctl daemon-reload || log "⚠️ تحذير: فشل بسيط في daemon-reload (تجاهل إن لم يوجد تغييرات وحدات)"
if systemctl restart sf-web.service; then
  log "✓ sf-web.service تم إعادة تشغيله"
else
  log "❌ فشل في restart sf-web.service – راجع journalctl -u sf-web.service"
fi

sleep 2

log "6) systemctl status (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

########################################
# 7) اختبار /health و /
########################################
log "7) اختبار HTTP على 127.0.0.1:8390 (health و root)"

if command -v curl >/dev/null 2>&1; then
  echo "---- GET /health ----" | tee -a "$LOG"
  curl -s http://127.0.0.1:8390/health || echo "❌ Web UI /health غير متاح" | tee -a "$LOG"
  echo "" | tee -a "$LOG"
  echo "---- GET / ----" | tee -a "$LOG"
  curl -s http://127.0.0.1:8390/ || echo "❌ Web UI / غير متاح" | tee -a "$LOG"
  echo "" | tee -a "$LOG"
else
  log "ℹ️ curl غير متاح – تخطّي اختبار HTTP المباشر"
fi

log "=================================================="
log "DONE – hf_sf_web_reset_minimal"
log "Report: $LOG"
log "=================================================="

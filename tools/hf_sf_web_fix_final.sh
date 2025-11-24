#!/usr/bin/env bash
# HyperFFactory – إصلاح نهائي لخدمة sf-web (SmartFriend Web UI)
# - يعيد بناء apps/web/app.py و web/run_web.py
# - يضمن أن /health و / يعملان
# - يلتزم بسياسة الهيكل الموحّد (تنفيذ من HyperFFactory، تعديل في /opt/smartfriend-suite فقط)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_fix_final_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – sf-web final fix"
log "Time : $TS"
log "Log  : $LOG"
log "SUITE: $SUITE_ROOT"
log "=================================================="

# تأكد من وجود المسارات
mkdir -p "$SUITE_ROOT/apps/web" "$SUITE_ROOT/web"

########################################
# 1) __init__.py
########################################
log "1) كتابة apps/web/__init__.py"

cat > "$SUITE_ROOT/apps/web/__init__.py" <<'PYEOF'
"""
SmartFriend Suite - Web package

هذا الملف يعرّف حزمة web ضمن apps/.
يمكن توسيعها لاحقاً لتضمين submodules أو إعدادات مشتركة.
"""
PYEOF

########################################
# 2) app.py – FastAPI app بسيط
########################################
log "2) كتابة apps/web/app.py (FastAPI app)"

cat > "$SUITE_ROOT/apps/web/app.py" <<'PYEOF'
from datetime import datetime

from fastapi import FastAPI
from fastapi.responses import HTMLResponse

app = FastAPI(
    title="SmartFriend Web UI",
    version="0.1.0",
    description="Minimal SmartFriend Web UI placeholder.",
)


@app.get("/health")
async def health():
    """
    نقطة صحّة بسيطة لـ sf-web.
    يمكن توسيعها لاحقاً لقراءة حالة الخدمات الأخرى.
    """
    return {
        "status": "ok",
        "service": "sf-web",
        "time": datetime.utcnow().isoformat(),
    }


@app.get("/", response_class=HTMLResponse)
async def index():
    """
    صفحة HTML بسيطة كواجهة موحّدة.
    """
    now = datetime.utcnow().isoformat()
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>SmartFriend Web UI</title>
</head>
<body>
  <h1>SmartFriend Web UI</h1>
  <p>Status: <strong>running</strong></p>
  <p>Time (UTC): {now}</p>
  <p>Health endpoint: <a href="/health">/health</a></p>
</body>
</html>"""
PYEOF

########################################
# 3) run_web.py – uvicorn launcher
########################################
log "3) كتابة web/run_web.py (uvicorn launcher)"

cat > "$SUITE_ROOT/web/run_web.py" <<'PYEOF'
#!/usr/bin/env python3
"""
SmartFriend Web UI launcher

هذا السكربت هو نقطة تشغيل sf-web.service.
يقوم بالآتي:
1) إضافة /opt/smartfriend-suite إلى sys.path
2) تشغيل FastAPI app من apps.web.app باستخدام Uvicorn
"""

import os
import sys
from pathlib import Path

import uvicorn


def main() -> None:
    # /opt/smartfriend-suite
    base_dir = Path(__file__).resolve().parents[1]
    if str(base_dir) not in sys.path:
        sys.path.insert(0, str(base_dir))

    host = os.environ.get("SF_WEB_HOST", "127.0.0.1")
    port = int(os.environ.get("SF_WEB_PORT", "8390"))
    log_level = os.environ.get("SF_WEB_LOG_LEVEL", "info")

    # apps.web.app:app
    uvicorn.run("apps.web.app:app", host=host, port=port, log_level=log_level)


if __name__ == "__main__":
    main()
PYEOF

########################################
# 4) صلاحيات وتشغيل
########################################
log "4) ضبط الصلاحيات"

# لو كان المستخدم smartfriend-suite موجود، اضبط الملكية
if id smartfriend-suite &>/dev/null; then
  chown -R smartfriend-suite:smartfriend-suite "$SUITE_ROOT/apps/web" "$SUITE_ROOT/web" || true
fi

chmod 755 "$SUITE_ROOT/web/run_web.py" || true

log "5) systemctl daemon-reload + restart sf-web.service"

systemctl daemon-reload
if systemctl restart sf-web.service; then
  log "✓ sf-web.service تم إعادة تشغيله (systemd)"
else
  log "⚠️ فشل في restart sf-web.service – راجع journalctl -u sf-web"
fi

sleep 2

log "6) systemctl status (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG" || true

log "7) اختبار /health و / على 127.0.0.1:8390"

curl -s http://127.0.0.1:8390/health \
  || echo "❌ Web UI /health غير متاح" | tee -a "$LOG"

curl -s http://127.0.0.1:8390/ \
  || echo "❌ Web UI / غير متاح" | tee -a "$LOG"

log "=================================================="
log "DONE – hf_sf_web_fix_final"
log "Report: $LOG"
log "=================================================="

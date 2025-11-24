#!/usr/bin/env bash
# HyperFFactory – Create stub apps.web.app for sf-web

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_web_create_stub_app_${TS}.log"

mkdir -p "$REPORT_DIR"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

log "=================================================="
log "HyperFFactory – Create stub apps.web.app"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "=================================================="

if [[ ! -d "$SUITE_ROOT" ]]; then
  log "❌ SUITE_ROOT غير موجود: $SUITE_ROOT"
  exit 1
fi

APPS_DIR="$SUITE_ROOT/apps"
WEB_DIR="$APPS_DIR/web"
APP_INIT="$WEB_DIR/__init__.py"
APP_FILE="$WEB_DIR/app.py"

log "1) إنشاء مجلد الحزمة apps/web إن لزم"
mkdir -p "$WEB_DIR"

log "2) كتابة __init__.py (حزمة web)"
cat > "$APP_INIT" <<'EOF_PY_INIT'
# SmartFriend Suite - apps.web package (stub)
# هذا الملف يُبقي الحزمة apps.web صالحة للاستيراد.
EOF_PY_INIT

log "3) كتابة app.py (FastAPI stub)"

cat > "$APP_FILE" <<'EOF_PY_APP'
"""
SmartFriend Web UI – Stub

يوفر:
- كائن FastAPI باسم app
- /health endpoint
- محاولة ربط memory_api.app (إن وجد) تحت /memory
"""

from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Web UI (Stub)",
    version="0.1.0-stub",
    description="Stub Web UI for sf-web.service – يوفر /health وربط اختياري مع memory_api."
)

# محاولة ربط واجهة الذاكرة إن كانت موجودة
memory_app = None
try:
    from apps import memory_api  # type: ignore
    memory_app = getattr(memory_api, "app", None)
except Exception:
    memory_app = None

if memory_app is not None:
    app.mount("/memory", memory_app)

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "component": "sf-web",
        "mode": "stub",
        "memory_mounted": bool(memory_app),
    }
EOF_PY_APP

log "✓ تم إنشاء/تحديث الملفات:"
log "   - $APP_INIT"
log "   - $APP_FILE"

log "4) ضبط الملكية إلى smartfriend-suite:smartfriend-suite"
chown -R smartfriend-suite:smartfriend-suite "$WEB_DIR"

log "5) اختبار استيراد apps.web.app داخل بيئة Python"

cd "$SUITE_ROOT"
if PYTHONPATH="$SUITE_ROOT:$SUITE_ROOT/web" python3 -c "from apps.web.app import app; print('IMPORT_OK', type(app))" 2>>"$LOG"; then
  log "✓ استيراد apps.web.app نجح (IMPORT_OK)"
else
  log "⚠️ استيراد apps.web.app فشل – راجع اللوج أعلاه."
fi

log "6) إعادة تشغيل sf-web.service"
if systemctl restart sf-web.service; then
  log "✓ تم تنفيذ systemctl restart sf-web.service"
else
  log "⚠️ فشل restart – راجع status بالأسفل."
fi

log "7) عرض systemctl status (أول 40 سطر)"
systemctl --no-pager -l status sf-web.service | sed -n '1,40p' | tee -a "$LOG"

log "8) تجربة /health على 8390"
{
  curl -s http://127.0.0.1:8390/health || echo "❌ Web UI /health غير متاح"
} | tee -a "$LOG"

log "=================================================="
log "DONE – hf_sf_web_create_stub_app"
log "Report: $LOG"
log "=================================================="

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

log "بدء إصلاح خدمات SmartFriend Suite الأساسية (memory/web/health/spider)..."

# 1) إيقاف الخدمات قبل الإصلاح لتجنب لوبات إعادة التشغيل
log "إيقاف الخدمات: sf-memory, sf-web, sf-health, sf-spider ..."
systemctl stop sf-memory.service sf-web.service sf-health.service sf-spider.service || true

echo
log "الخطوة 2: إصلاح صلاحيات venv الخاصة بالسيوت (لمشكلة PermissionError في sf-health)"

VENVD="/opt/smartfriend-suite/smartfriend/venv"
if [ -d "$VENVD" ]; then
  log "ضبط صلاحيات القراءة والتنفيذ للجميع على: $VENVD"
  chmod -R a+rX "$VENVD"
else
  log "تحذير: venv غير موجود في $VENVD (تخطي إصلاح الصلاحيات)"
fi

echo
log "الخطوة 3: ضمان وجود حزمة apps مع memory_api و web (بدون الكتابة فوق أي ملفات موجودة)"

create_apps_pkg_tree() {
  local BASE="$1"
  [ -d "$BASE" ] || return 0

  local APPDIR="$BASE/apps"
  mkdir -p "$APPDIR"

  if [ ! -f "$APPDIR/__init__.py" ]; then
    log "إنشاء $APPDIR/__init__.py"
    cat > "$APPDIR/__init__.py" <<'PYEOF'
"""
SmartFriend Suite - apps package
Placeholder init file to ensure `apps.*` imports work.
"""
PYEOF
  else
    log "اكتشاف __init__.py موجود في $APPDIR (لن يتم تعديله)."
  fi

  # memory_api placeholder (إذا غير موجود)
  if [ ! -f "$APPDIR/memory_api.py" ]; then
    log "إنشاء placeholder لـ apps.memory_api في $APPDIR/memory_api.py"
    cat > "$APPDIR/memory_api.py" <<'PYEOF'
"""
SmartFriend Suite - Memory API (placeholder)

هذا التطبيق مؤقت لضمان عمل sf-memory.service
لحين ربطه بتطبيق الذاكرة الحقيقي.
"""

from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Memory API (placeholder)",
    version="0.1.0",
)

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "component": "memory-api", "mode": "placeholder"}

@app.get("/", tags=["root"])
async def root():
    return {
        "message": "SmartFriend Memory API placeholder is running.",
        "detail": "هذا endpoint مؤقت إلى أن يتم توصيله بمحرك الذاكرة الفعلي."
    }
PYEOF
  else
    log "اكتشاف apps.memory_api موجود مسبقًا في $APPDIR (لن يتم تعديله)."
  fi

  # web placeholder (إذا غير موجود)
  if [ ! -f "$APPDIR/web.py" ]; then
    log "إنشاء placeholder لـ apps.web في $APPDIR/web.py"
    cat > "$APPDIR/web.py" <<'PYEOF'
"""
SmartFriend Suite - Web UI (placeholder)

تطبيق ويب بسيط يعمل على البورت 8390 عن طريق sf-web.service.
يمكن لاحقًا استبداله بواجهة متقدمة مرتبطة بـ FFactory/Unified.
"""

from fastapi import FastAPI
from fastapi.responses import HTMLResponse, RedirectResponse

app = FastAPI(
    title="SmartFriend Web UI (placeholder)",
    version="0.1.0",
)

@app.get("/health", tags=["health"])
async def health():
    return {"status": "ok", "component": "web-ui", "mode": "placeholder"}

@app.get("/", response_class=HTMLResponse, tags=["ui"])
async def index():
    # يمكن تعديل الرابط لاحقًا ليتكامل مع لوحة ffactory
    html = """
    <!DOCTYPE html>
    <html lang="ar">
    <head>
        <meta charset="utf-8" />
        <title>SmartFriend Web UI</title>
        <style>
            body { font-family: sans-serif; direction: rtl; text-align: right; margin: 40px; }
            .box { max-width: 600px; margin: auto; border: 1px solid #ccc; padding: 20px; border-radius: 8px; }
            a { text-decoration: none; }
        </style>
    </head>
    <body>
        <div class="box">
            <h1>SmartFriend Web UI (Placeholder)</h1>
            <p>واجهة ويب مبدئية للسيوت. تم تشغيلها فقط لضمان صحة المسار والخدمة.</p>
            <p>لوحة FFactory الحالية متاحة عبر <code>/ffactory/docs</code> من خلال Nginx.</p>
            <p><a href="/ffactory/docs">الانتقال إلى لوحة FFactory (عبر Nginx)</a></p>
        </div>
    </body>
    </html>
    """
    return html

@app.get("/redirect/ffactory")
async def redirect_ffactory():
    return RedirectResponse(url="/ffactory/docs")
PYEOF
  else
    log "اكتشاف apps.web موجود مسبقًا في $APPDIR (لن يتم تعديله)."
  fi
}

# إنشاء الشجرة في احتمالين:
create_apps_pkg_tree "/opt/smartfriend-suite"
create_apps_pkg_tree "/opt/smartfriend-suite/smartfriend"

echo
log "الخطوة 4: إصلاح سكربت sf_spider_run.sh (مشكلة date extra operand)"

SPIDER_CANDIDATES=$(find /opt/smartfriend-suite -maxdepth 6 -type f -name 'sf_spider_run.sh' 2>/dev/null || true)

if [ -z "$SPIDER_CANDIDATES" ]; then
  log "تحذير: لم يتم العثور على sf_spider_run.sh تحت /opt/smartfriend-suite"
else
  echo "$SPIDER_CANDIDATES" | while read -r f; do
    [ -n "$f" ] || continue
    log "محاولة إصلاح date في: $f"
    # استبدال النموذج الخاطئ إن وجد (بدون تعديل أي شيء آخر)
    sed -i 's/date +%Y-%m-%d %H:%M:%S/date "+%Y-%m-%d %H:%M:%S"/g' "$f" || true
  done
fi

echo
log "الخطوة 5: إعادة تشغيل الخدمات الأساسية والتحقق من حالتها"

systemctl daemon-reload || true

systemctl restart sf-memory.service  || log "تحذير: فشل restart لـ sf-memory (تحقق يدويًا من logs)."
systemctl restart sf-web.service     || log "تحذير: فشل restart لـ sf-web (تحقق يدويًا من logs)."
systemctl restart sf-health.service  || log "تحذير: فشل restart لـ sf-health (تحقق يدويًا من logs)."
systemctl restart sf-spider.service  || log "تحذير: فشل restart لـ sf-spider (تحقق يدويًا من logs)."

echo
log "ملخص الحالة بعد الإصلاح (status مختصر):"
systemctl --no-pager --plain status sf-memory.service sf-web.service sf-health.service sf-spider.service | sed -n '1,80p' || true

echo
log "انتهى sf_suite_fix_core_services.sh"

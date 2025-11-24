#!/usr/bin/env bash
# HyperFFactory – Minimal SmartFriend sf-* repair (core/health/memory/web)

set -Eeuo pipefail

ROOT="/root/HyperFFactory"
SUITE_ROOT="/opt/smartfriend-suite"
REPORT_DIR="$ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="$REPORT_DIR/hf_sf_minimal_repair_${TS}.log"

log() {
  echo "[$(date '+%F %T')] $*" | tee -a "$LOG"
}

header() {
  echo "" | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
  echo "$*" | tee -a "$LOG"
  echo "=====================================================" | tee -a "$LOG"
}

log "====================================================="
log "HyperFFactory – Minimal SmartFriend sf-* repair"
log "ROOT       : $ROOT"
log "SUITE_ROOT : $SUITE_ROOT"
log "TIME       : $TS"
log "LOG        : $LOG"
log "====================================================="

if [ ! -d "$SUITE_ROOT" ]; then
  log "❌ SUITE_ROOT غير موجود: $SUITE_ROOT"
  exit 1
fi

###############################################################################
# 1) إنشاء باكجات services.ffactory و ops + كود بسيط لـ core/health
###############################################################################
header "1) Create minimal Python packages: services.ffactory & ops"

mkdir -p "$SUITE_ROOT/services/ffactory" "$SUITE_ROOT/ops"

[ ! -f "$SUITE_ROOT/services/__init__.py" ] && echo '# SmartFriend services package' > "$SUITE_ROOT/services/__init__.py"
[ ! -f "$SUITE_ROOT/services/ffactory/__init__.py" ] && echo '# SmartFriend ffactory subpackage' > "$SUITE_ROOT/services/ffactory/__init__.py"
[ ! -f "$SUITE_ROOT/ops/__init__.py" ] && echo '# SmartFriend ops package' > "$SUITE_ROOT/ops/__init__.py"

# services.ffactory.simple_api – نسخة بسيطة
if [ ! -f "$SUITE_ROOT/services/ffactory/simple_api.py" ]; then
  log "✓ كتابة services/ffactory/simple_api.py (نسخة بسيطة)"
  cat > "$SUITE_ROOT/services/ffactory/simple_api.py" <<'PYEOF'
from fastapi import FastAPI

app = FastAPI(title="SmartFriend Core Minimal")

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "component": "sf-core",
        "mode": "minimal",
    }

@app.get("/")
async def root():
    return {
        "message": "SmartFriend Core Minimal API",
        "docs": "/docs",
    }
PYEOF
else
  log "ℹ️ simple_api.py موجود مسبقاً – لن نعدّله"
fi

# ops.health_gate – نسخة بسيطة
if [ ! -f "$SUITE_ROOT/ops/health_gate.py" ]; then
  log "✓ كتابة ops/health_gate.py (نسخة بسيطة)"
  cat > "$SUITE_ROOT/ops/health_gate.py" <<'PYEOF'
from fastapi import FastAPI

app = FastAPI(title="SmartFriend Health Gate Minimal")

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "component": "sf-health",
        "mode": "minimal",
    }

@app.get("/")
async def root():
    return {
        "message": "SmartFriend Health Gate Minimal",
        "docs": "/docs",
    }
PYEOF
else
  log "ℹ️ health_gate.py موجود مسبقاً – لن نعدّله"
fi

###############################################################################
# 2) استرجاع apps.memory_api.py إلى /opt/smartfriend-suite/apps
###############################################################################
header "2) Restore apps.memory_api.py under /opt/smartfriend-suite/apps"

APPS_DIR="$SUITE_ROOT/apps"
mkdir -p "$APPS_DIR"

if [ ! -f "$APPS_DIR/__init__.py" ]; then
  echo '# SmartFriend apps package' > "$APPS_DIR/__init__.py"
fi

if [ -f "$APPS_DIR/memory_api.py" ]; then
  log "ℹ️ apps/memory_api.py موجود مسبقاً في $APPS_DIR – لن نعدّله"
else
  # محاولة العثور على نسخة احتياطية داخل HyperFFactory
  BACKUP_MEM="$(find "$ROOT/imported/opt/smartfriend-suite" -maxdepth 6 -path '*/apps/memory_api.py' 2>/dev/null | head -n 1 || true)"
  if [ -n "$BACKUP_MEM" ] && [ -f "$BACKUP_MEM" ]; then
    log "✓ العثور على نسخة احتياطية: $BACKUP_MEM"
    cp "$BACKUP_MEM" "$APPS_DIR/memory_api.py"
    log "✓ نسخنا memory_api.py إلى $APPS_DIR/memory_api.py"
  else
    log "⚠️ لم نجد نسخة احتياطية لـ apps/memory_api.py – سيتم بقاء sf-memory في وضع فشل حتى تزويد الكود"
  fi
fi

###############################################################################
# 3) تجهيز web/run_web.py في /opt/smartfriend-suite/web
###############################################################################
header "3) Prepare web/run_web.py under /opt/smartfriend-suite/web"

WEB_SRC="$ROOT/collected_scripts_from_opt/run_web.py"
WEB_DST_DIR="$SUITE_ROOT/web"
WEB_DST="$WEB_DST_DIR/run_web.py"

mkdir -p "$WEB_DST_DIR"

if [ -f "$WEB_SRC" ] && [ ! -f "$WEB_DST" ]; then
  cp "$WEB_SRC" "$WEB_DST"
  log "✓ نسخنا run_web.py من $WEB_SRC إلى $WEB_DST"
elif [ -f "$WEB_DST" ]; then
  log "ℹ️ run_web.py موجود مسبقاً في $WEB_DST – لن نعدّله"
else
  log "⚠️ لم نجد $WEB_SRC ولن ننشئ run_web.py تلقائياً – sf-web قد يظل متوقفاً"
fi

###############################################################################
# 4) تعديل الملكية إلى smartfriend-suite إن وُجد
###############################################################################
header "4) Fix ownership for services/ops/apps/web (if user exists)"

if id smartfriend-suite >/dev/null 2>&1; then
  chown -R smartfriend-suite:smartfriend-suite \
    "$SUITE_ROOT/services" \
    "$SUITE_ROOT/ops" \
    "$SUITE_ROOT/apps" \
    "$SUITE_ROOT/web"
  log "✓ عدلنا الملكية إلى smartfriend-suite:smartfriend-suite"
else
  log "ℹ️ مستخدم smartfriend-suite غير موجود – تخطي chown"
fi

###############################################################################
# 5) Drop-in للوحدات: sf-core / sf-health / sf-memory / sf-web
###############################################################################
header "5) Write systemd drop-ins 70-hf-fix.conf for sf-core/sf-health/sf-memory/sf-web"

ensure_dir() {
  local d="$1"
  [ -d "$d" ] || mkdir -p "$d"
}

# sf-core
if systemctl list-unit-files | awk '{print $1}' | grep -q '^sf-core.service$'; then
  ensure_dir /etc/systemd/system/sf-core.service.d
  cat > /etc/systemd/system/sf-core.service.d/70-hf-fix.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn services.ffactory.simple_api:app --host 127.0.0.1 --port 8211 --workers 1
CONF
  log "✓ كتبنا Drop-in 70-hf-fix.conf لـ sf-core.service"
else
  log "ℹ️ sf-core.service غير موجود – تخطي"
fi

# sf-health
if systemctl list-unit-files | awk '{print $1}' | grep -q '^sf-health.service$'; then
  ensure_dir /etc/systemd/system/sf-health.service.d
  cat > /etc/systemd/system/sf-health.service.d/70-hf-fix.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn ops.health_gate:app --host 127.0.0.1 --port 8210 --workers 1 --timeout-keep-alive 30
CONF
  log "✓ كتبنا Drop-in 70-hf-fix.conf لـ sf-health.service"
else
  log "ℹ️ sf-health.service غير موجود – تخطي"
fi

# sf-memory
if systemctl list-unit-files | awk '{print $1}' | grep -q '^sf-memory.service$'; then
  ensure_dir /etc/systemd/system/sf-memory.service.d
  cat > /etc/systemd/system/sf-memory.service.d/70-hf-fix.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=
ExecStart=/usr/bin/python3 -m uvicorn apps.memory_api:app --host 127.0.0.1 --port 8214 --workers 1
CONF
  log "✓ كتبنا Drop-in 70-hf-fix.conf لـ sf-memory.service"
else
  log "ℹ️ sf-memory.service غير موجود – تخطي"
fi

# sf-web
if systemctl list-unit-files | awk '{print $1}' | grep -q '^sf-web.service$'; then
  ensure_dir /etc/systemd/system/sf-web.service.d
  cat > /etc/systemd/system/sf-web.service.d/70-hf-fix.conf <<'CONF'
[Service]
WorkingDirectory=/opt/smartfriend-suite/web
ExecStart=
ExecStart=/usr/bin/python3 /opt/smartfriend-suite/web/run_web.py
CONF
  log "✓ كتبنا Drop-in 70-hf-fix.conf لـ sf-web.service"
else
  log "ℹ️ sf-web.service غير موجود – تخطي"
fi

###############################################################################
# 6) إيقاف sf-bot مؤقتاً (venv مفقود)
###############################################################################
header "6) Disable sf-bot (venv missing)"

if systemctl list-unit-files | awk '{print $1}' | grep -q '^sf-bot.service$'; then
  systemctl disable --now sf-bot.service || true
  log "✓ تم إيقاف وتعطيل sf-bot.service مؤقتاً"
else
  log "ℹ️ sf-bot.service غير موجود – تخطي"
fi

###############################################################################
# 7) daemon-reload + restart
###############################################################################
header "7) systemd daemon-reload + restart sf-core/sf-health/sf-memory/sf-web"

systemctl daemon-reload

for s in sf-core sf-health sf-memory sf-web; do
  if systemctl list-unit-files | awk '{print $1}' | grep -q "^${s}.service$"; then
    log "▶️ إعادة تشغيل ${s}.service"
    if systemctl restart "${s}.service"; then
      log "✓ ${s}.service أعيد تشغيله"
    else
      log "⚠️ فشل في إعادة تشغيل ${s}.service"
    fi
  else
    log "ℹ️ ${s}.service غير موجود – تخطي"
  fi
done

header "8) Final status snapshot"

systemctl --no-pager -l status sf-core sf-health sf-memory sf-web sf-bot 2>&1 | tee -a "$LOG" || true

log "====================================================="
log "DONE – hf_sf_minimal_repair finished"
log "Report: $LOG"
log "====================================================="

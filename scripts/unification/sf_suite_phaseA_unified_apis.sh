#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

echo "============================================================"
echo "      SmartFriend Suite – Phase A: Unified APIs Bring-Up"
echo "============================================================"

BASE_DIR="/opt/smartfriend-suite"
VENV_PY="$BASE_DIR/venv/bin/python"
APP_DIR="$BASE_DIR/apps"
BACKUP_DIR="$BASE_DIR/backup_phaseA_$(date '+%Y%m%d_%H%M%S')"
SYSTEMD_DIR="/etc/systemd/system"
ENV_FILE="/etc/smartfriend/sf_suite.env"

log(){ echo "[$(date '+%F %T')] $*"; }

mkdir -p "$BACKUP_DIR/apps" "$BACKUP_DIR/systemd"

log "1) Backup للملفات الحالية (apps + systemd)"

# Backup Python modules (إن وجدت)
for f in \
  "$APP_DIR/unified/__init__.py" \
  "$APP_DIR/memory_api.py" \
  "$APP_DIR/web.py" \
  "$BASE_DIR/health.py"
do
  if [ -f "$f" ]; then
    log "   - Backup $f"
    cp -a "$f" "$BACKUP_DIR/apps/"
  fi
done

# Backup systemd units (إن وجدت)
for u in sf-unified.service sf-memory.service sf-web.service sf-health.service; do
  if [ -f "$SYSTEMD_DIR/$u" ]; then
    log "   - Backup unit $u"
    cp -a "$SYSTEMD_DIR/$u" "$BACKUP_DIR/systemd/"
  fi
done

echo
log "2) ضمان وجود ملف البيئة بصيغة مقبولة لـ systemd (بدون export)"

mkdir -p "$(dirname "$ENV_FILE")"
if [ ! -f "$ENV_FILE" ]; then
  cat > "$ENV_FILE" <<'ENVV'
SF_ENV="production"
SF_TIMEZONE="Asia/Kuwait"
SF_INSTANCE_NAME="vmi-smartfriend-suite"

SF_UNIFIED_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
SF_MEMORY_DB="/opt/smartfriend-suite/var/db/memory.db"

SF_CORE_PORT="8211"
SF_UNIFIED_PORT="8220"
SF_MEMORY_PORT="8214"
SF_WEB_PORT="8390"
ENVV
  log "   - تم إنشاء ENV جديد: $ENV_FILE"
else
  log "   - موجود بالفعل، لن أعبث بالقيم؛ المهم: لا يوجد سطر يبدأ بـ export"
  # إزالة export لو موجودة
  sed -i 's/^export[[:space:]]\+//g' "$ENV_FILE"
fi

echo
log "3) كتابة Unified API (apps/unified/__init__.py)"

mkdir -p "$APP_DIR/unified"
cat > "$APP_DIR/unified/__init__.py" <<'PYUNIFIED'
from fastapi import FastAPI, Request
import os
import socket
import time

app = FastAPI(
    title="SmartFriend Unified API",
    version="1.0.0",
    description="Unified gateway facade for SmartFriend Suite."
)

def _meta():
    return {
        "service": "sf-unified",
        "version": "1.0.0",
        "hostname": socket.gethostname(),
        "env": os.getenv("SF_ENV", "unknown"),
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

@app.get("/health")
async def health():
    meta = _meta()
    meta["status"] = "ok"
    return meta

@app.get("/info")
async def info():
    return _meta()

@app.get("/ping")
async def ping():
    return {"pong": True, **_meta()}
PYUNIFIED

chmod 640 "$APP_DIR/unified/__init__.py"

echo
log "4) كتابة Memory API (apps/memory_api.py)"

cat > "$APP_DIR/memory_api.py" <<'PYMEM'
from fastapi import FastAPI
from pathlib import Path
import os
import sqlite3
import time
from typing import Dict, Any

UNIFIED_DB = os.getenv("SF_UNIFIED_DB", "/opt/smartfriend-suite/var/db/smartfriend_unified.db")
MEMORY_DB = os.getenv("SF_MEMORY_DB", "/opt/smartfriend-suite/var/db/memory.db")

app = FastAPI(
    title="SmartFriend Memory API",
    version="1.0.0",
    description="Thin memory/knowledge facade for SmartFriend Suite."
)

def db_info(path: str) -> Dict[str, Any]:
    p = Path(path)
    info: Dict[str, Any] = {
        "path": str(p),
        "exists": p.exists(),
        "size_bytes": p.stat().st_size if p.exists() else 0,
    }
    if p.exists():
        try:
            conn = sqlite3.connect(str(p))
            cur = conn.cursor()
            # نحاول قراءة عدد الجداول فقط كمؤشر حياة
            cur.execute("SELECT count(*) FROM sqlite_master WHERE type='table';")
            info["tables"] = cur.fetchone()[0]
            conn.close()
        except Exception as e:
            info["error"] = str(e)
    return info

@app.get("/health")
async def health():
    return {
        "service": "sf-memory",
        "status": "ok",
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }

@app.get("/stats")
async def stats():
    return {
        "unified_db": db_info(UNIFIED_DB),
        "memory_db": db_info(MEMORY_DB),
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
PYMEM

chmod 640 "$APP_DIR/memory_api.py"

echo
log "5) كتابة Web UI بسيطة (apps/web.py)"

cat > "$APP_DIR/web.py" <<'PYWEB'
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
import os
import time

app = FastAPI(
    title="SmartFriend Suite Web UI",
    version="1.0.0",
    description="Minimal dashboard placeholder for SmartFriend Suite."
)

def _link(path: str, label: str) -> str:
    return f'<li><a href="{path}">{label}</a></li>'

@app.get("/", response_class=HTMLResponse)
async def index():
    items = [
        _link("/core/health", "Core API /health (via nginx)"),
        _link("/unified/health", "Unified API /health"),
        _link("/memory/health", "Memory API /health"),
        _link("/memory/stats", "Memory /stats"),
        _link("/nginx-health", "Nginx /nginx-health"),
    ]
    html = f"""
    <html>
      <head>
        <meta charset="utf-8" />
        <title>SmartFriend Suite Dashboard</title>
      </head>
      <body>
        <h1>SmartFriend Suite – Dashboard</h1>
        <p>Environment: {os.getenv("SF_ENV", "unknown")}</p>
        <p>Time: {time.strftime("%Y-%m-%d %H:%M:%S")}</p>
        <h2>Quick Links</h2>
        <ul>
          {''.join(items)}
        </ul>
      </body>
    </html>
    """
    return html
PYWEB

chmod 640 "$APP_DIR/web.py"

echo
log "6) كتابة Health API موحد (health.py في جذر السيوت)"

cat > "$BASE_DIR/health.py" <<'PYHEALTH'
from fastapi import FastAPI
import time
import socket
import os

app = FastAPI(
    title="SmartFriend Suite Health",
    version="1.0.0",
)

@app.get("/health")
async def health():
    return {
        "service": "sf-health",
        "status": "ok",
        "hostname": socket.gethostname(),
        "env": os.getenv("SF_ENV", "unknown"),
        "time": time.strftime("%Y-%m-%d %H:%M:%S"),
    }
PYHEALTH

chmod 640 "$BASE_DIR/health.py"

echo
log "7) تعريف وحدات systemd جديدة (sf-unified, sf-memory, sf-web, sf-health)"

cat > "$SYSTEMD_DIR/sf-unified.service" <<'UNIT_UNIFIED'
[Unit]
Description=SmartFriend Suite - unified API (8220)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn apps.unified:app --host 127.0.0.1 --port 8220
Restart=always
RestartSec=3
User=smartfriend-suite
Group=smartfriend-suite

[Install]
WantedBy=multi-user.target
UNIT_UNIFIED

cat > "$SYSTEMD_DIR/sf-memory.service" <<'UNIT_MEMORY'
[Unit]
Description=SmartFriend Suite - memory API (8214)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn apps.memory_api:app --host 127.0.0.1 --port 8214
Restart=always
RestartSec=3
User=smartfriend-suite
Group=smartfriend-suite

[Install]
WantedBy=multi-user.target
UNIT_MEMORY

cat > "$SYSTEMD_DIR/sf-web.service" <<'UNIT_WEB'
[Unit]
Description=SmartFriend Web UI (8390)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn apps.web:app --host 127.0.0.1 --port 8390
Restart=always
RestartSec=3
User=smartfriend-suite
Group=smartfriend-suite

[Install]
WantedBy=multi-user.target
UNIT_WEB

cat > "$SYSTEMD_DIR/sf-health.service" <<'UNIT_HEALTH'
[Unit]
Description=SmartFriend Suite - health
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn health:app --host 127.0.0.1 --port 8215
Restart=always
RestartSec=5
User=smartfriend-suite
Group=smartfriend-suite

[Install]
WantedBy=multi-user.target
UNIT_HEALTH

echo
log "8) daemon-reload + enable/start الخدمات الجديدة"

systemctl daemon-reload

systemctl enable sf-unified.service sf-memory.service sf-web.service sf-health.service >/dev/null 2>&1 || true
systemctl restart sf-unified.service sf-memory.service sf-web.service sf-health.service || true

echo
log "9) Snapshot سريع للبورتات المهمة"
ss -tulpn 2>/dev/null | grep -E ':8211|:8214|:8220|:8390|:8215|:80' || true

echo
log "10) حالة الخدمات"
systemctl --no-pager --plain status sf-unified.service sf-memory.service sf-web.service sf-health.service | sed -n '1,80p' || true

echo
echo "============================================================"
echo "  Phase A انتهت – السيوت عندها الآن APIs موحدة أساسية"
echo "  Backup موجود هنا: $BACKUP_DIR"
echo "============================================================"

#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[$(date '+%F %T')] $*"; }

log "🔧 إصلاح الملفات المفقودة في مجلد apps..."

# إنشاء الهيكل الأساسي
APPS_DIR="/opt/smartfriend-suite/apps"
mkdir -p "$APPS_DIR"/{memory_api,web,health,unified,core}

# 1. إصلاح Memory API
log "📝 إنشاء Memory API..."
cat > "$APPS_DIR/memory_api/__init__.py" <<'MEMORY_INIT'
# Memory API Module
MEMORY_INIT

cat > "$APPS_DIR/memory_api/app.py" <<'MEMORY_APP'
from fastapi import FastAPI
import os

app = FastAPI(
    title="SmartFriend Memory API",
    description="Memory service for SmartFriend Suite",
    version="1.0.0"
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "memory", "port": 8214}

@app.get("/status")
async def status():
    return {
        "service": "memory",
        "status": "active", 
        "version": "1.0.0",
        "endpoints": ["/health", "/status"]
    }

@app.get("/")
async def root():
    return {"message": "SmartFriend Memory API is running"}
MEMORY_APP

# 2. إصلاح Web UI
log "📝 إنشاء Web UI..."
cat > "$APPS_DIR/web/__init__.py" <<'WEB_INIT'
# Web UI Module
WEB_INIT

cat > "$APPS_DIR/web/app.py" <<'WEB_APP'
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse

app = FastAPI(
    title="SmartFriend Web UI",
    description="Web interface for SmartFriend Suite",
    version="1.0.0"
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "web", "port": 8390}

@app.get("/", response_class=HTMLResponse)
async def root():
    return """
    <html>
        <head>
            <title>SmartFriend Suite</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
                .ok { background: #d4edda; color: #155724; }
            </style>
        </head>
        <body>
            <h1>🚀 SmartFriend Suite</h1>
            <div class="status ok">✅ System is operational</div>
            <p>Web UI is running on port 8390</p>
        </body>
    </html>
    """
WEB_APP

# 3. إصلاح Health API
log "📝 إنشاء Health API..."
cat > "$APPS_DIR/health/__init__.py" <<'HEALTH_INIT'
# Health API Module
HEALTH_INIT

cat > "$APPS_DIR/health/app.py" <<'HEALTH_APP'
from fastapi import FastAPI
import psutil

app = FastAPI(
    title="SmartFriend Health API",
    description="Health monitoring service",
    version="1.0.0"
)

@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "health", 
        "port": 8215,
        "timestamp": __import__("datetime").datetime.now().isoformat()
    }

@app.get("/system")
async def system_info():
    return {
        "cpu_percent": psutil.cpu_percent(),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent
    }

@app.get("/services")
async def services_status():
    return {
        "memory": {"port": 8214, "status": "checking"},
        "web": {"port": 8390, "status": "checking"},
        "health": {"port": 8215, "status": "active"}
    }
HEALTH_APP

# 4. إصلاح Unified API
log "📝 إنشاء Unified API..."
cat > "$APPS_DIR/unified/__init__.py" <<'UNIFIED_INIT'
# Unified API Module
UNIFIED_INIT

cat > "$APPS_DIR/unified/app.py" <<'UNIFIED_APP'
from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Unified API",
    description="Unified gateway for all services",
    version="1.0.0"
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "unified", "port": 8220}

@app.get("/")
async def root():
    return {
        "message": "SmartFriend Unified API Gateway",
        "services": {
            "memory": "http://localhost:8214",
            "web": "http://localhost:8390", 
            "health": "http://localhost:8215",
            "core": "http://localhost:8211"
        }
    }
UNIFIED_APP

# 5. إصلاح Core API
log "📝 إنشاء Core API..."
cat > "$APPS_DIR/core/__init__.py" <<'CORE_INIT'
# Core API Module
CORE_INIT

cat > "$APPS_DIR/core/app.py" <<'CORE_APP'
from fastapi import FastAPI

app = FastAPI(
    title="SmartFriend Core API",
    description="Core logic service",
    version="1.0.0"
)

@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "core", "port": 8211}

@app.get("/")
async def root():
    return {"message": "SmartFriend Core API is running"}
CORE_APP

log "✅ تم إنشاء جميع الملفات الأساسية"

# 6. إعادة تشغيل الخدمات
log "🔄 إعادة تشغيل الخدمات..."
SERVICES=("sf-memory.service" "sf-web.service" "sf-health.service" "sf-unified.service")

for service in "${SERVICES[@]}"; do
    log "🔄 إعادة تشغيل $service..."
    systemctl stop "$service" 2>/dev/null || true
    sleep 2
    if systemctl restart "$service"; then
        sleep 3
        if systemctl is-active "$service" &>/dev/null; then
            log "✅ $service: شغال بنجاح"
        else
            log "❌ $service: فشل في البقاء نشطاً"
        fi
    else
        log "⚠️ $service: فشل في إعادة التشغيل"
    fi
done

log "🎉 اكتمل الإصلاح!"
echo "=== التحقق النهائي ==="
systemctl is-active sf-memory sf-web sf-health sf-unified

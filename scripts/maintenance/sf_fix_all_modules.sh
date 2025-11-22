#!/bin/bash
echo "=== إصلاح هيكل الموديولات لجميع الخدمات ==="

# إصلاح memory
echo "🔧 إصلاح sf-memory.service..."
cat > /opt/smartfriend-suite/apps/memory/app.py << 'MEMORY_EOF'
from fastapi import FastAPI
app = FastAPI(title="SmartFriend Memory API")
@app.get("/")
async def root(): return {"message": "SmartFriend Memory API"}
@app.get("/health")
async def health(): return {"status": "healthy"}
MEMORY_EOF

cat > /etc/systemd/system/sf-memory.service << 'MEMORY_SVC'
[Unit]
Description=SmartFriend Suite - memory API (8214)
After=network.target
[Service]
Type=exec
User=root
Group=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn apps.memory.app:app --host 127.0.0.1 --port 8214
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
MEMORY_SVC

# إصلاح web
echo "🔧 إصلاح sf-web.service..."
cat > /opt/smartfriend-suite/apps/web/app.py << 'WEB_EOF'
from fastapi import FastAPI
app = FastAPI(title="SmartFriend Web UI")
@app.get("/")
async def root(): return {"message": "SmartFriend Web UI"}
@app.get("/health")
async def health(): return {"status": "healthy"}
WEB_EOF

cat > /etc/systemd/system/sf-web.service << 'WEB_SVC'
[Unit]
Description=SmartFriend Web UI (8390)
After=network.target
[Service]
Type=exec
User=root
Group=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn apps.web.app:app --host 0.0.0.0 --port 8390
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
WEB_SVC

# تطبيق التغييرات
systemctl daemon-reload
systemctl start sf-memory.service sf-web.service

echo "✅ تم إصلاح الهيكل الأساسي"
echo "=== الحالة النهائية ==="
systemctl status sf-unified.service sf-memory.service sf-web.service --no-pager -l | grep -E "(Active:|Main PID)"

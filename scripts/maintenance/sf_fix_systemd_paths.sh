#!/bin/bash
echo "🔧 إصلاح مسارات systemd للخدمات الفاشلة"

# 1. إصلاح sf-unified.service
echo "📦 إصلاح sf-unified.service..."
cat > /etc/systemd/system/sf-unified.service <<'UNIFIED'
[Unit]
Description=SmartFriend Unified API Gateway
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/usr/bin/python3 -m uvicorn apps.unified:app --host 0.0.0.0 --port 8220 --workers 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIFIED

# 2. إصلاح sf-memory.service
echo "🧠 إصلاح sf-memory.service..."
cat > /etc/systemd/system/sf-memory.service <<'MEMORY'
[Unit]
Description=SmartFriend Memory API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/usr/bin/python3 -m uvicorn apps.memory:app --host 0.0.0.0 --port 8214 --workers 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
MEMORY

# 3. إصلاح sf-web.service
echo "🌐 إصلاح sf-web.service..."
cat > /etc/systemd/system/sf-web.service <<'WEB'
[Unit]
Description=SmartFriend Web Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/usr/bin/python3 -m uvicorn apps.web:app --host 0.0.0.0 --port 8390 --workers 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
WEB

# 4. إصلاح sf-health.service
echo "❤️ إصلاح sf-health.service..."
cat > /etc/systemd/system/sf-health.service <<'HEALTH'
[Unit]
Description=SmartFriend Health API
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/smartfriend-suite
EnvironmentFile=/etc/smartfriend/sf_suite.env
ExecStart=/usr/bin/python3 -m uvicorn apps.health:app --host 0.0.0.0 --port 8090 --workers 1
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
HEALTH

echo "✅ تم إصلاح جميع ملفات systemd"

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

log "[*] تحديث sf-learning.service (Restart=on-failure)..."
cat > /etc/systemd/system/sf-learning.service <<'UNIT'
[Unit]
Description=SmartFriend Suite - Brain Continuous Learning Loop
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_brain_learning_loop.sh
Restart=on-failure
RestartSec=30
Environment=SF_ENV=production

[Install]
WantedBy=multi-user.target
UNIT

log "[*] تحديث sf-spider.service (Restart=on-failure)..."
cat > /etc/systemd/system/sf-spider.service <<'UNIT'
[Unit]
Description=SmartFriend Spider (Web Harvester)
After=network.target smartfrind-api.service smartfrind-gateway.service
Wants=smartfrind-api.service smartfrind-gateway.service

[Service]
Type=simple
WorkingDirectory=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/scripts/sf_spider_run.sh
Restart=on-failure
RestartSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

log "[*] عمل daemon-reload لـ systemd..."
systemctl daemon-reload

log "[*] إعادة تشغيل sf-learning و sf-spider..."
systemctl restart sf-learning.service sf-spider.service || true

log "[*] حالة مختصرة للخدمتين:"
systemctl --no-pager --full status sf-learning.service sf-spider.service | sed -n '1,12p' || true

log "[*] تم."

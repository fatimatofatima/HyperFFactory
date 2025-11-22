#!/usr/bin/env bash
set -Eeuo pipefail

echo "== SmartFriend / FFactory Nginx Fix =="

CONF="/etc/nginx/sites-available/smartfriend.conf"
BACKUP_DIR="/root/nginx_backups"
mkdir -p "$BACKUP_DIR"

# نسخة احتياطية من الإعداد السابق إن وجد
if [ -f "$CONF" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  cp "$CONF" "$BACKUP_DIR/smartfriend.conf.$TS.bak"
  echo "[i] Backup => $BACKUP_DIR/smartfriend.conf.$TS.bak"
fi

cat > "$CONF" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    client_max_body_size 32m;

    # Health check لـ Nginx نفسه
    location /nginx-health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # الصفحة الرئيسية → إعادة توجيه للوحة FFactory
    location = / {
        return 302 /ffactory/;
    }

    # لوحة FFactory (واجهة الويب – خلفها خدمة البورت 8000)
    location /ffactory/ {
        proxy_pass         http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # Smart Core API (8211)
    location /core/ {
        proxy_pass         http://127.0.0.1:8211/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # Unified API (8220)
    location /unified/ {
        proxy_pass         http://127.0.0.1:8220/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # Memory API (8214)
    location /memory/ {
        proxy_pass         http://127.0.0.1:8214/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }
}
NGINX

# تفعيل الموقع وتعطيل الـ default القديم
ln -sf "$CONF" /etc/nginx/sites-enabled/smartfriend.conf

if [ -f /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default
fi

echo "[i] Testing Nginx config..."
nginx -t

echo "[i] Reloading Nginx..."
systemctl reload nginx

echo "[✓] Nginx routes updated."

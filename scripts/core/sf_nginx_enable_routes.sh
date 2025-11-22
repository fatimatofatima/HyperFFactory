#!/usr/bin/env bash
set -Eeuo pipefail

TS="$(date '+%Y%m%d_%H%M%S')"
CONF="/etc/nginx/sites-enabled/smartfriend.conf"
BACKUP="/etc/nginx/sites-enabled/smartfriend.conf.backup.${TS}"

echo "🔀 تفعيل مسارات Nginx /memory/ و /dashboard/"
echo "1) نسخ احتياطي: ${BACKUP}"

if [ -f "$CONF" ]; then
    cp "$CONF" "$BACKUP"
    echo "✅ تم إنشاء نسخة احتياطية من smartfriend.conf"
else
    echo "⚠️  لم أجد $CONF – سيتم إنشاء ملف جديد."
fi

cat > /tmp/smartfriend_new.conf <<'CONFEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 62.171.172.105 _;

    client_max_body_size 32m;

    location /nginx-health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # الصفحة الرئيسية – إعادة توجيه للوحة السيوت
    location = / {
        return 302 /dashboard/;
    }

    # ffactory / unified gateway (يجب أن يكون على نفس البورت الذي يعمل عليه sf-unified)
    location /ffactory/ {
        proxy_pass         http://127.0.0.1:8210/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    location /unified/ {
        proxy_pass         http://127.0.0.1:8210/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # واجهة core الداخلية
    location /core/ {
        proxy_pass         http://127.0.0.1:8211/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # Memory API
    location /memory/ {
        proxy_pass         http://127.0.0.1:8214/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }

    # لوحة ويب السيوت
    location /dashboard/ {
        proxy_pass         http://127.0.0.1:8390/;
        proxy_http_version 1.1;
        proxy_set_header   Host               $host;
        proxy_set_header   X-Real-IP          $remote_addr;
        proxy_set_header   X-Forwarded-For    $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  $scheme;
    }
}
CONFEOF

echo "2) استبدال smartfriend.conf بالتكوين الجديد"
cp /tmp/smartfriend_new.conf "$CONF"

echo "3) اختبار إعدادات Nginx..."
nginx -t

echo "4) إعادة تحميل Nginx..."
systemctl reload nginx

echo "✅ تم تفعيل /memory/ و /dashboard/ في Nginx (بشرط أن sf-memory و sf-web يعملان على 8214 و 8390)."

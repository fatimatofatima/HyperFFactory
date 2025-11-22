#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[SF-NGINX] $*"; }

CONF_FILE="/etc/nginx/sites-enabled/smartfriend.conf"

# ===============================
# إعدادات الـ Backends (عدّلها عند الحاجة)
# ===============================

# Unified API (يُستخدم لـ /unified/ وربما /ffactory/ إن أحببت توحيدهما لاحقًا)
UNIFIED_BACKEND="http://127.0.0.1:8220/"

# Core API
CORE_BACKEND="http://127.0.0.1:8211/"

# Memory API
MEMORY_BACKEND="http://127.0.0.1:8214/"

# Root redirect (يمكن تغييره لاحقًا لـ /suite/ أو /dashboard/)
ROOT_REDIRECT="/ffactory/docs"

log "كتابة smartfriend.conf جديد إلى: $CONF_FILE"

cat > "$CONF_FILE" <<NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name 62.171.172.105 _;

    client_max_body_size 32m;

    # Health check لـ Nginx نفسه
    location /nginx-health {
        access_log off;
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    # الجذر: تحويل مباشر للواجهة (يمكن تغييره لاحقًا لـ Web UI)
    location = / {
        return 302 ${ROOT_REDIRECT};
    }

    # /ffactory/ نفسها → نحافظ عليها كما هي (docs على unified/ffactory backend)
    location = /ffactory/ {
        return 302 /ffactory/docs;
    }

    # لوحة FFactory / Unified API على البورت 8220 (نتركها كما هي الآن)
    location /ffactory/ {
        proxy_pass         ${UNIFIED_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    # Smart Core API
    location /core/ {
        proxy_pass         ${CORE_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    # Unified API direct (بدون prefix ffactory)
    location /unified/ {
        proxy_pass         ${UNIFIED_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    # Memory API
    location /memory/ {
        proxy_pass         ${MEMORY_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }
}
NGINX

log "اختبار إعدادات nginx..."
nginx -t

log "إعادة تحميل nginx..."
systemctl reload nginx

log "انتهى تحديث smartfriend.conf."

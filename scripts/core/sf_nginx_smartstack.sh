#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

DOMAIN="${1:-62.171.172.105}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; exit 1; }

echo "=========================================="
echo "   🌐 SmartFriend Stack - Nginx Gateway"
echo "=========================================="
echo

log "DOMAIN = $DOMAIN"

# 1) التأكد من وجود nginx
if ! command -v nginx >/dev/null 2>&1; then
    log "nginx غير مثبت – تثبيت..."
    apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
else
    log "✅ nginx مثبت بالفعل."
fi

# 2) تعطيل الموقع الافتراضي
if [ -L /etc/nginx/sites-enabled/default ]; then
    log "تعطيل /etc/nginx/sites-enabled/default"
    rm -f /etc/nginx/sites-enabled/default
fi

# 3) إنشاء كونفيج SmartFriend
CONF="/etc/nginx/sites-available/smartfriend.conf"
BACKUP="${CONF}.$(date +%Y%m%d_%H%M%S).bak"

if [ -f "$CONF" ]; then
    log "نسخة احتياطية من الكونفيج القديم: $BACKUP"
    cp -a "$CONF" "$BACKUP"
fi

log "كتابة الكونفيج الجديد في $CONF"

cat > "$CONF" <<NGINXCONF
# SmartFriend Stack - Nginx Gateway
# تم الإنشاء بواسطة sf_nginx_smartstack.sh

upstream smartfriend_unified {
    server 127.0.0.1:8220;
}

upstream smartfriend_core {
    server 127.0.0.1:8211;
}

upstream ffactory_main {
    server 127.0.0.1:8000;
}

upstream ffactory_gateway {
    server 127.0.0.1:8170;
}

server {
    listen 80;
    server_name ${DOMAIN};

    # Unified API كـ landing page
    location / {
        proxy_pass http://smartfriend_unified/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Smart Core API
    location /core/ {
        proxy_pass http://smartfriend_core/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # FFactory Main (لوحة / خدمات)
    location /ffactory/ {
        proxy_pass http://ffactory_main/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # FFactory Gateway
    location /ff-gw/ {
        proxy_pass http://ffactory_gateway/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # health بسيط للـ Nginx نفسه
    location /nginx-health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
NGINXCONF

# 4) تفعيل الموقع
if [ ! -L /etc/nginx/sites-enabled/smartfriend.conf ]; then
    ln -s "$CONF" /etc/nginx/sites-enabled/smartfriend.conf
    log "تم إنشاء symlink: /etc/nginx/sites-enabled/smartfriend.conf"
fi

# 5) اختبار وإعادة تحميل
log "اختبار إعدادات Nginx..."
if nginx -t; then
    log "✅ إعدادات Nginx صحيحة – عمل reload..."
    systemctl reload nginx
    log "✅ تم تفعيل SmartFriend Gateway على http://${DOMAIN}/"
else
    error "❌ فشل اختبار إعدادات Nginx – راجع مخرجات nginx -t."
fi

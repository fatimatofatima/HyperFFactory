#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

CONF="/etc/nginx/sites-enabled/smartfriend.conf"
BACKUP_DIR="/opt/smartfriend-suite/nginx_backups"
mkdir -p "$BACKUP_DIR"

TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP="$BACKUP_DIR/smartfriend.conf.${TS}.bak"

DRY_RUN="${DRY_RUN:-1}"

# Upstreams (تقدر تغيّرها قبل التشغيل)
FFACTORY_UPSTREAM="${FFACTORY_UPSTREAM:-http://127.0.0.1:8210/}"
UNIFIED_UPSTREAM="${UNIFIED_UPSTREAM:-http://127.0.0.1:8210/}"
CORE_UPSTREAM="${CORE_UPSTREAM:-http://127.0.0.1:8211/}"
MEMORY_UPSTREAM="${MEMORY_UPSTREAM:-http://127.0.0.1:8214/}"

log(){ echo "[$(date '+%F %T')] $*"; }

render_config() {
  cat <<NGINXEOF
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

    # صفحة الدخول الافتراضية
    location = / {
        return 302 /ffactory/docs;
    }

    # FFactory / Unified / Core / Memory – يمكن تعديل الـ upstreams من متغيرات البيئة
    location /ffactory/ {
        proxy_pass         ${FFACTORY_UPSTREAM};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    location /unified/ {
        proxy_pass         ${UNIFIED_UPSTREAM};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    location /core/ {
        proxy_pass         ${CORE_UPSTREAM};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }

    # memory مؤقتاً يمكن تعليقها بتغيير MEMORY_UPSTREAM أو حذف الـ location
    location /memory/ {
        proxy_pass         ${MEMORY_UPSTREAM};
        proxy_http_version 1.1;
        proxy_set_header   Host               \$host;
        proxy_set_header   X-Real-IP          \$remote_addr;
        proxy_set_header   X-Forwarded-For    \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto  \$scheme;
    }
}
NGINXEOF
}

main() {
  log "SmartFriend Suite – Nginx switch for smartfriend.conf"
  log "DRY_RUN         = $DRY_RUN"
  log "FFACTORY_UPSTREAM = $FFACTORY_UPSTREAM"
  log "UNIFIED_UPSTREAM  = $UNIFIED_UPSTREAM"
  log "CORE_UPSTREAM     = $CORE_UPSTREAM"
  log "MEMORY_UPSTREAM   = $MEMORY_UPSTREAM"

  if [[ ! -f "$CONF" ]]; then
    log "تحذير: $CONF غير موجود. سيتم إنشاؤه جديداً."
  else
    log "سيتم أخذ نسخة احتياطية إلى: $BACKUP"
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "------------------------------------------------------------"
    echo "DRY-RUN: Config الناتج الذي سيتم كتابته في $CONF:"
    echo "------------------------------------------------------------"
    render_config
    echo "------------------------------------------------------------"
    log "DRY-RUN فقط – لن يتم تغيير smartfriend.conf أو إعادة تحميل nginx."
    exit 0
  fi

  # تنفيذ فعلي
  if [[ -f "$CONF" ]]; then
    cp "$CONF" "$BACKUP"
    log "تم أخذ نسخة احتياطية: $BACKUP"
  fi

  render_config > "$CONF"
  log "تم توليد $CONF"

  log "اختبار إعداد nginx via nginx -t"
  if nginx -t; then
    log "nginx -t OK – سيتم إعادة تحميل nginx"
    systemctl reload nginx
    log "تم systemctl reload nginx"
  else
    log "خطأ في nginx -t – لن يتم reload. راجع الرسائل أعلاه."
    exit 1
  fi
}

main

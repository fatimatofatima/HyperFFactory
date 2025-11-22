#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

APP_ROOT="/opt/smartfriend-suite"

log "⏹️ إيقاف الخدمات..."
systemctl stop sf-memory sf-web sf-health sf-unified 2>/dev/null || true

log "📁 ضمان هيكل حزمة apps..."
if [ -d "$APP_ROOT/apps" ]; then
  # apps نفسها كحزمة
  touch "$APP_ROOT/apps/__init__.py"
  chown smartfriend-suite:smartfriend-suite "$APP_ROOT/apps/__init__.py"

  # الحزم الفرعية التي نستخدمها مع systemd
  for d in memory_api web health unified core; do
    if [ -d "$APP_ROOT/apps/$d" ]; then
      touch "$APP_ROOT/apps/$d/__init__.py"
      chown smartfriend-suite:smartfriend-suite "$APP_ROOT/apps/$d/__init__.py"
    fi
  done
fi

log "🧩 إنشاء drop-in لتهيئة WorkingDirectory و PYTHONPATH..."
for svc in sf-memory sf-web sf-health sf-unified; do
  dir="/etc/systemd/system/${svc}.service.d"
  mkdir -p "$dir"
  cat > "$dir/30-workingdir.conf" <<UNIT
[Service]
WorkingDirectory=$APP_ROOT
Environment=PYTHONPATH=$APP_ROOT
UNIT
done

log "🔄 إعادة تحميل systemd..."
systemctl daemon-reload

log "🚀 تشغيل الخدمات..."
systemctl start sf-memory sf-web sf-health sf-unified || true

log "📊 حالة الخدمات (مختصرة)..."
systemctl --no-pager --full status sf-memory sf-web sf-health sf-unified | sed -n '1,60p'

log "🌐 اختبار health endpoints:"
curl -s http://127.0.0.1:8214/health || echo "❌ Memory API غير متاح"
curl -s http://127.0.0.1:8390/health || echo "❌ Web UI غير متاح"
curl -s http://127.0.0.1:8215/health || echo "❌ Health API غير متاح"
curl -s http://127.0.0.1:8220/health || echo "❌ Unified API غير متاح"

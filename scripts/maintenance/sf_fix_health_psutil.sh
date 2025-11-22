#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

VENV_DIR="/opt/smartfriend-suite/venv"
PY_BIN="$VENV_DIR/bin/python"

log "⏹️ إيقاف خدمة sf-health..."
systemctl stop sf-health.service 2>/dev/null || true

log "🐍 تثبيت/تحديث psutil داخل venv الصحيح: $VENV_DIR"
/usr/bin/sudo -u smartfriend-suite "$PY_BIN" -m pip install --upgrade psutil

log "🔎 اختبار استيراد psutil داخل نفس venv..."
/usr/bin/sudo -u smartfriend-suite "$PY_BIN" <<'PYEOF'
import sys, psutil
print("Python exe :", sys.executable)
print("Python vers:", sys.version.split()[0])
print("psutil ver :", psutil.__version__)
print("psutil file:", psutil.__file__)
PYEOF

log "🚀 إعادة تشغيل sf-health..."
systemctl restart sf-health.service

sleep 3

log "📊 حالة sf-health (مختصرة)..."
systemctl status sf-health.service --no-pager -l | sed -n '1,20p'

log "🌐 اختبار endpoint /health على 8215..."
curl -s http://127.0.0.1:8215/health || echo "❌ فشل الوصول إلى /health"
echo

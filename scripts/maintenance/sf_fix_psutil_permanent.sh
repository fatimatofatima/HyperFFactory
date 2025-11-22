#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

VENV_DIR="/opt/smartfriend-suite/venv"
PY_BIN="$VENV_DIR/bin/python"

log "🔧 إصلاح أذونات virtualenv..."
chown -R smartfriend-suite:smartfriend-suite "$VENV_DIR"
chmod -R u+w "$VENV_DIR"

log "🐍 تثبيت psutil في virtualenv smartfriend-suite..."
sudo -u smartfriend-suite "$PY_BIN" -m pip install --upgrade psutil

log "🔍 التحقق من تثبيت psutil..."
sudo -u smartfriend-suite "$PY_BIN" -c "
import sys, psutil
print('✅ Python executable:', sys.executable)
print('✅ Python version:', sys.version.split()[0])
print('✅ psutil version:', psutil.__version__)
print('✅ psutil path:', psutil.__file__)
"

log "🚀 إعادة تشغيل Health API..."
systemctl restart sf-health.service

sleep 3

log "🧪 اختبار Health API..."
curl -s http://127.0.0.1:8215/health && echo " ✅ Health API - FINALLY WORKING!" || echo " ❌ Health API still failing"

log "📊 الحالة النهائية لجميع الخدمات:"
systemctl status sf-memory sf-web sf-health sf-unified --no-pager --lines=2

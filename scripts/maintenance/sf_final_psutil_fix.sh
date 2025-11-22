#!/usr/bin/env bash
set -Eeuo pipefail

log(){ echo "[$(date '+%F %T')] $*"; }

VENV_DIR="/opt/smartfriend-suite/venv"

log "🔧 إصلاح أذونات virtualenv بشكل كامل..."
# إيقاف جميع الخدمات أولاً
systemctl stop sf-memory sf-web sf-health sf-unified 2>/dev/null || true

# إصلاح الملكية والأذونات
chown -R smartfriend-suite:smartfriend-suite "$VENV_DIR"
chmod -R 755 "$VENV_DIR"
find "$VENV_DIR" -type d -exec chmod 755 {} \;
find "$VENV_DIR" -type f -exec chmod 644 {} \;

# تنظيف psutil القديم إذا كان موجوداً
rm -rf "$VENV_DIR/lib/python3.10/site-packages/psutil"* 2>/dev/null || true

log "🐍 تثبيت psutil مع أذونات root أولاً (للتأكد من عدم وجود مشاكل أذونات)..."
# تثبيت كـ root أولاً للتأكد من عدم وجود مشاكل أذونات
"$VENV_DIR/bin/python" -m pip install --upgrade psutil

log "🔍 التحقق من تثبيت psutil..."
"$VENV_DIR/bin/python" -c "
import sys, psutil
print('✅ Python executable:', sys.executable)
print('✅ Python version:', sys.version.split()[0])
print('✅ psutil version:', psutil.__version__)
print('✅ psutil path:', psutil.__file__)
"

log "🚀 إعادة تشغيل جميع الخدمات..."
systemctl start sf-memory sf-web sf-health sf-unified

sleep 5

log "🧪 اختبار جميع الـ APIs..."
echo "=== النتائج النهائية ==="
curl -s http://127.0.0.1:8214/health && echo " ✅ Memory API" || echo " ❌ Memory API"
curl -s http://127.0.0.1:8390/health && echo " ✅ Web UI" || echo " ❌ Web UI" 
curl -s http://127.0.0.1:8215/health && echo " ✅ Health API" || echo " ❌ Health API"
curl -s http://127.0.0.1:8220/health && echo " ✅ Unified API" || echo " ❌ Unified API"

log "📊 الحالة النهائية:"
systemctl status sf-memory sf-web sf-health sf-unified --no-pager --lines=2

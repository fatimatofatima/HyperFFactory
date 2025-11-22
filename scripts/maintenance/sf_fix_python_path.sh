#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[$(date '+%F %T')] $*"; }

APPS_DIR="/opt/smartfriend-suite/apps"
VENV_DIR="/opt/smartfriend-suite/venv"

# إيقاف الخدمات أولاً
log "⏹️ إيقاف الخدمات..."
systemctl stop sf-memory sf-web sf-health sf-unified 2>/dev/null || true

# 1. التحقق من هيكل الملفات
log "📁 التحقق من هيكل الملفات..."
find "$APPS_DIR" -name "*.py" -type f | head -10

# 2. إنشاء ملف __init__.py في المجلد الرئيسي إذا لم يكن موجوداً
log "📝 إنشاء ملفات __init__.py..."
for dir in "$APPS_DIR" "$APPS_DIR/memory_api" "$APPS_DIR/web" "$APPS_DIR/health" "$APPS_DIR/unified" "$APPS_DIR/core"; do
    if [ -d "$dir" ]; then
        touch "$dir/__init__.py"
        chown smartfriend-suite:smartfriend-suite "$dir/__init__.py"
    fi
done

# 3. التحقق من محتوى الملفات
log "🔍 التحقق من محتوى ملفات التطبيق..."
for app in memory_api web health unified; do
    if [ -f "$APPS_DIR/$app/app.py" ]; then
        echo "✅ $app/app.py موجود"
        head -5 "$APPS_DIR/$app/app.py"
    else
        echo "❌ $app/app.py غير موجود"
    fi
done

# 4. اختبار استيراد Python
log "🐍 اختبار استيراد Python..."
sudo -u smartfriend-suite bash <<'TESTPYTHON'
export PYTHONPATH="/opt/smartfriend-suite:$PYTHONPATH"
cd /opt/smartfriend-suite

echo "=== اختبار استيراد apps ==="
python -c "
import sys
print('Python path:', sys.path)
try:
    from apps.memory_api.app import app
    print('✅ Memory API: تم الاستيراد بنجاح')
except Exception as e:
    print('❌ Memory API فشل:', e)

try:
    from apps.web.app import app as web_app
    print('✅ Web API: تم الاستيراد بنجاح')
except Exception as e:
    print('❌ Web API فشل:', e)

try:
    from apps.health.app import app as health_app
    print('✅ Health API: تم الاستيراد بنجاح')
except Exception as e:
    print('❌ Health API فشل:', e)
"
TESTPYTHON

# 5. تحديث ملفات systemd لإضافة PYTHONPATH
log "🔧 تحديث ملفات systemd..."
for service in sf-memory sf-web sf-health sf-unified; do
    if [ -f "/etc/systemd/system/$service.service" ]; then
        # إنشاء مجلد drop-in إذا لم يكن موجوداً
        mkdir -p "/etc/systemd/system/$service.service.d"
        
        # تحديث ملف البيئة
        cat > "/etc/systemd/system/$service.service.d/30-pythonpath.conf" <<ENVCONF
[Service]
Environment=PYTHONPATH=/opt/smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
ENVCONF
    fi
done

# 6. بدلاً من ذلك، إنشاء ملفات تشغيل مباشرة
log "🔄 إنشاء ملفات تشغيل بديلة..."

# Memory API
cat > "/opt/smartfriend-suite/run_memory_api.py" <<'RUNMEM'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/smartfriend-suite')

from apps.memory_api.app import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8214)
RUNMEM

# Web UI
cat > "/opt/smartfriend-suite/run_web.py" <<'RUNWEB'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/smartfriend-suite')

from apps.web.app import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8390)
RUNWEB

# Health API
cat > "/opt/smartfriend-suite/run_health.py" <<'RUNHEALTH'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/smartfriend-suite')

from apps.health.app import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8215)
RUNHEALTH

# Unified API
cat > "/opt/smartfriend-suite/run_unified.py" <<'RUNUNIFIED'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/opt/smartfriend-suite')

from apps.unified.app import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8220)
RUNUNIFIED

chmod +x /opt/smartfriend-suite/run_*.py
chown smartfriend-suite:smartfriend-suite /opt/smartfriend-suite/run_*.py

# 7. تحديث ملفات systemd لاستخدام الملفات المباشرة
log "🔧 تحديث systemd لاستخدام الملفات المباشرة..."

# Memory Service
cat > /etc/systemd/system/sf-memory.service <<'MEMSRV'
[Unit]
Description=SmartFriend Suite - Memory API (8214)
After=network.target
Wants=network.target

[Service]
Type=exec
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_memory_api.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
MEMSRV

# Web Service
cat > /etc/systemd/system/sf-web.service <<'WEBSRV'
[Unit]
Description=SmartFriend Web UI (8390)
After=network.target
Wants=network.target

[Service]
Type=exec
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_web.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
WEBSRV

# Health Service
cat > /etc/systemd/system/sf-health.service <<'HEALTHSRV'
[Unit]
Description=SmartFriend Suite - Health API (8215)
After=network.target
Wants=network.target

[Service]
Type=exec
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_health.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
HEALTHSRV

# Unified Service
cat > /etc/systemd/system/sf-unified.service <<'UNIFIEDSRV'
[Unit]
Description=SmartFriend Suite - Unified API (8220)
After=network.target
Wants=network.target

[Service]
Type=exec
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_unified.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIFIEDSRV

# 8. إعادة تحميل وتشغيل الخدمات
log "🔄 إعادة تحميل systemd..."
systemctl daemon-reload

log "🚀 تشغيل الخدمات..."
services=("sf-memory" "sf-web" "sf-health" "sf-unified")

for service in "${services[@]}"; do
    log "▶️ تشغيل $service..."
    systemctl enable "$service"
    systemctl start "$service"
    sleep 3
    
    if systemctl is-active --quiet "$service"; then
        log "✅ $service: يعمل بنجاح"
    else
        log "❌ $service: فشل في التشغيل"
        journalctl -u "$service" -n 5 --no-pager
    fi
done

# 9. اختبار النهائي
log "🧪 اختبار النهائي..."
sleep 5
echo ""
echo "🌐 اختبار ال APIs:"
curl -s http://127.0.0.1:8214/health && echo " ✅ Memory API" || echo " ❌ Memory API"
curl -s http://127.0.0.1:8390/health && echo " ✅ Web UI" || echo " ❌ Web UI"
curl -s http://127.0.0.1:8215/health && echo " ✅ Health API" || echo " ❌ Health API"
curl -s http://127.0.0.1:8220/health && echo " ✅ Unified API" || echo " ❌ Unified API"

echo ""
echo "📊 حالة الخدمات:"
systemctl status sf-memory sf-web sf-health sf-unified --no-pager --lines=2

log "🎉 اكتمل الإصلاح!"

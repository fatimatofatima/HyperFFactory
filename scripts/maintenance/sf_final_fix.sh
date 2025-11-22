#!/usr/bin/env bash
set -Eeuo pipefail

log() { echo "[$(date '+%F %T')] $*"; }

APPS_DIR="/opt/smartfriend-suite/apps"
VENV_DIR="/opt/smartfriend-suite/venv"

# إيقاف الخدمات أولاً
log "⏹️ إيقاف الخدمات..."
systemctl stop sf-memory sf-web sf-health sf-unified 2>/dev/null || true

# 1. التحقق من Python وبيئة virtualenv
log "🐍 التحقق من بيئة Python..."
sudo -u smartfriend-suite /opt/smartfriend-suite/venv/bin/python -c "
import sys
print('Python executable:', sys.executable)
print('Python path:', sys.prefix)
print('Python version:', sys.version)
"

# 2. اختبار الاستيراد مع المسار الصحيح
log "🔧 اختبار استيراد التطبيقات..."
sudo -u smartfriend-suite bash <<'TESTPYTHON'
export PYTHONPATH="/opt/smartfriend-suite:$PYTHONPATH"
cd /opt/smartfriend-suite

echo "=== اختبار استيراد Memory API ==="
/opt/smartfriend-suite/venv/bin/python -c "
import sys
print('Python path:', sys.path)
try:
    from apps.memory_api.app import app
    print('✅ Memory API: تم الاستيراد بنجاح')
    print('✅ FastAPI app:', type(app))
except Exception as e:
    print('❌ Memory API فشل:', e)
    import traceback
    traceback.print_exc()
"

echo "=== اختبار استيراد Web API ==="
/opt/smartfriend-suite/venv/bin/python -c "
try:
    from apps.web.app import app as web_app
    print('✅ Web API: تم الاستيراد بنجاح')
    print('✅ FastAPI app:', type(web_app))
except Exception as e:
    print('❌ Web API فشل:', e)
    import traceback
    traceback.print_exc()
"

echo "=== اختبار استيراد Health API ==="
/opt/smartfriend-suite/venv/bin/python -c "
try:
    from apps.health.app import app as health_app
    print('✅ Health API: تم الاستيراد بنجاح')
    print('✅ FastAPI app:', type(health_app))
except Exception as e:
    print('❌ Health API فشل:', e)
    import traceback
    traceback.print_exc()
"
TESTPYTHON

# 3. إنشاء ملفات تشغيل مباشرة مع المسار الصحيح
log "🔄 إنشاء ملفات تشغيل بديلة..."

# Memory API
cat > "/opt/smartfriend-suite/run_memory_api.py" <<'RUNMEM'
#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.memory_api.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Memory API على المنفذ 8214...")
        uvicorn.run(app, host="0.0.0.0", port=8214, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Memory API: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
RUNMEM

# Web UI
cat > "/opt/smartfriend-suite/run_web.py" <<'RUNWEB'
#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.web.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Web UI على المنفذ 8390...")
        uvicorn.run(app, host="0.0.0.0", port=8390, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Web UI: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
RUNWEB

# Health API
cat > "/opt/smartfriend-suite/run_health.py" <<'RUNHEALTH'
#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.health.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Health API على المنفذ 8215...")
        uvicorn.run(app, host="0.0.0.0", port=8215, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Health API: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
RUNHEALTH

# Unified API
cat > "/opt/smartfriend-suite/run_unified.py" <<'RUNUNIFIED'
#!/usr/bin/env python3
import sys
import os

# إضافة المسار إلى sys.path
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from apps.unified.app import app
    import uvicorn
    
    if __name__ == "__main__":
        print("🚀 بدء تشغيل Unified API على المنفذ 8220...")
        uvicorn.run(app, host="0.0.0.0", port=8220, log_level="info")
except Exception as e:
    print(f"❌ فشل في تشغيل Unified API: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
RUNUNIFIED

chmod +x /opt/smartfriend-suite/run_*.py
chown smartfriend-suite:smartfriend-suite /opt/smartfriend-suite/run_*.py

# 4. اختبار الملفات الجديدة
log "🧪 اختبار الملفات الجديدة..."
sudo -u smartfriend-suite /opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_memory_api.py --help 2>/dev/null && echo "✅ Memory API script works" || echo "❌ Memory API script failed"
sudo -u smartfriend-suite /opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_web.py --help 2>/dev/null && echo "✅ Web UI script works" || echo "❌ Web UI script failed"

# 5. تحديث ملفات systemd لاستخدام المسار الكامل
log "🔧 تحديث ملفات systemd..."

# Memory Service
cat > /etc/systemd/system/sf-memory.service <<'MEMSRV'
[Unit]
Description=SmartFriend Suite - Memory API (8214)
After=network.target
Wants=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_memory_api.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

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
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_web.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

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
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_health.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

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
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PYTHONPATH=/opt/smartfriend-suite
ExecStart=/opt/smartfriend-suite/venv/bin/python /opt/smartfriend-suite/run_unified.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIFIEDSRV

# 6. إعادة تحميل وتشغيل الخدمات
log "🔄 إعادة تحميل systemd..."
systemctl daemon-reload

log "🚀 تشغيل الخدمات..."
services=("sf-memory" "sf-web" "sf-health" "sf-unified")

for service in "${services[@]}"; do
    log "▶️ تشغيل $service..."
    systemctl enable "$service"
    systemctl start "$service"
    sleep 5
    
    if systemctl is-active --quiet "$service"; then
        log "✅ $service: يعمل بنجاح"
        # عرض السجلات الأخيرة
        journalctl -u "$service" -n 3 --no-pager | grep -v "Started\|Starting" || true
    else
        log "❌ $service: فشل في التشغيل"
        journalctl -u "$service" -n 10 --no-pager
    fi
done

# 7. اختبار النهائي
log "🧪 اختبار النهائي..."
sleep 8
echo ""
echo "🌐 اختبار ال APIs:"

test_api() {
    local name=$1
    local port=$2
    if curl -s --connect-timeout 5 "http://127.0.0.1:$port/health" > /dev/null; then
        echo "✅ $name (port $port) - متاح"
        return 0
    else
        echo "❌ $name (port $port) - غير متاح"
        return 1
    fi
}

test_api "Memory API" 8214
test_api "Web UI" 8390
test_api "Health API" 8215
test_api "Unified API" 8220

echo ""
echo "📊 حالة الخدمات:"
for service in "${services[@]}"; do
    status=$(systemctl is-active "$service")
    if [ "$status" = "active" ]; then
        echo "✅ $service: $status"
    else
        echo "❌ $service: $status"
    fi
done

echo ""
echo "🔍 فتحات الشبكة:"
ss -tulpn | grep -E ':(8214|8390|8215|8220)' || echo "⚠️  لا توجد فتحات شبكة نشطة"

log "🎉 اكتمل الإصلاح!"

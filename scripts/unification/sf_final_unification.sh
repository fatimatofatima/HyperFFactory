#!/bin/bash
set -e

echo "🎯 البدء في التوحيد النهائي لـ SmartFriend Suite"
echo "⏰ الوقت: $(date)"
echo "================================================"

# 1. تجميد Legacy النهائي
echo ""
echo "🔴 1. تجميد خدمات Legacy النهائي..."
sudo systemctl stop smartfrind-* 2>/dev/null || true
sudo systemctl disable smartfrind-* 2>/dev/null || true
sudo systemctl mask smartfrind-* 2>/dev/null || true

# تنظيف البورتات المتضاربة
echo "🧹 تنظيف البورتات المتضاربة..."
for port in 8210 8211 8221 8222; do
    sudo fuser -k $port/tcp 2>/dev/null || true
done

# 2. إيقاف الخدمات المتضاربة في sf-*
echo ""
echo "🟡 2. إيقاف الخدمات المتضاربة في sf-*..."
sudo systemctl stop sf-unified.service 2>/dev/null || true
sudo systemctl stop sf-memory.service 2>/dev/null || true
sudo systemctl stop sf-cognitive.service 2>/dev/null || true
sudo systemctl disable sf-unified.service 2>/dev/null || true
sudo systemctl disable sf-memory.service 2>/dev/null || true

# 3. إنشاء وتمكين الخدمات الموحدة
echo ""
echo "🟢 3. إنشاء وتمكين الخدمات الموحدة..."

# إنشاء خدمة Gateway الموحدة
cat > /tmp/sf-gateway.service << 'SERVICE_EOF'
[Unit]
Description=SmartFriend Main Gateway (8220)
After=network.target

[Service]
Type=simple
User=smartfriend-suite
Group=smartfriend-suite
WorkingDirectory=/opt/smartfriend-suite
Environment=PATH=/opt/smartfriend-suite/venv/bin:/usr/bin:/bin
ExecStart=/opt/smartfriend-suite/venv/bin/python -m uvicorn services.unified.hybrid_api_enhanced:app --host 0.0.0.0 --port 8220 --workers 2
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

sudo cp /tmp/sf-gateway.service /etc/systemd/system/
sudo systemctl daemon-reload

# 4. تفعيل الخدمات الأساسية
echo "🚀 تفعيل الخدمات الأساسية..."
sudo systemctl enable --now sf-core.service 2>/dev/null || true
sudo systemctl enable --now sf-memory-fixed.service 2>/dev/null || true
sudo systemctl enable --now sf-gateway.service
sudo systemctl enable --now sf-web.service 2>/dev/null || true
sudo systemctl enable --now sf-health.service 2>/dev/null || true

# 5. توحيد البوتات
echo ""
echo "🤖 4. توحيد البوتات..."
sudo systemctl stop sf-bot-dev.service sf-bot-model.service sf-bot-assistant.service sf-telegram.service sf-telegram-audit.service 2>/dev/null || true
sudo systemctl disable sf-bot-dev.service sf-bot-model.service sf-bot-assistant.service sf-telegram.service sf-telegram-audit.service 2>/dev/null || true

# الإبقاء على البوتات الأساسية فقط
sudo systemctl enable --now sf-bot.service 2>/dev/null || true
sudo systemctl enable --now sf-bot-programmer.service 2>/dev/null || true

# 6. تحديث Nginx
echo ""
echo "🌐 5. تحديث Nginx..."
cat > /tmp/nginx-smartfriend-core.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    client_max_body_size 32m;
    
    # الصفحة الرئيسية
    location / {
        proxy_pass http://127.0.0.1:8390/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Unified API
    location /api/ {
        proxy_pass http://127.0.0.1:8220/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Memory API
    location /memory/ {
        proxy_pass http://127.0.0.1:8214/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Health API
    location /health/ {
        proxy_pass http://127.0.0.1:8215/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Core API
    location /core/ {
        proxy_pass http://127.0.0.1:8383/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

sudo cp /tmp/nginx-smartfriend-core.conf /etc/nginx/sites-available/smartfriend
sudo ln -sf /etc/nginx/sites-available/smartfriend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 7. الانتظار وتفقد الحالة
echo ""
echo "⏳ 6. الانتظار لاستقرار الخدمات..."
sleep 10

# 8. العرض النهائي
echo ""
echo "================================================"
echo "✅ اكتمل التوحيد النهائي لـ SmartFriend Suite!"
echo "⏰ الوقت: $(date)"
echo ""

echo "📊 الحالة النهائية للخدمات:"
echo "---------------------------"
systemctl list-units "sf-*" --state=active --no-pager | grep -E "(sf-core|sf-memory|sf-gateway|sf-web|sf-health|sf-bot|sf-bot-programmer)"

echo ""
echo "🌐 البورتات النشطة:"
echo "-------------------"
netstat -tlnp | grep -E ':(8214|8220|8390|8215|8383)' | awk '{print "📍 " $4 " - " $7}'

echo ""
echo "🔍 اختبار الواجهات:"
echo "-------------------"
# اختبار Web UI
if curl -s -f http://127.0.0.1:8390/ >/dev/null; then
    echo "✅ Web UI (8390) - نشط"
else
    echo "❌ Web UI (8390) - غير متاح"
fi

# اختبار Unified API
if curl -s -f http://127.0.0.1:8220/health >/dev/null; then
    echo "✅ Unified API (8220) - نشط"
else
    echo "❌ Unified API (8220) - غير متاح"
fi

# اختبار Memory API
if curl -s -f http://127.0.0.1:8214/ >/dev/null; then
    echo "✅ Memory API (8214) - نشط"
else
    echo "❌ Memory API (8214) - غير متاح"
fi

# اختبار Health API
if curl -s -f http://127.0.0.1:8215/ >/dev/null; then
    echo "✅ Health API (8215) - نشط"
else
    echo "❌ Health API (8215) - غير متاح"
fi

echo ""
echo "🎯 الخدمات النشطة:"
echo "------------------"
systemctl list-units "sf-*" --state=active --no-pager | grep "loaded.*active" | wc -l | awk '{print "📈 " $1 " خدمة نشطة"}'

echo ""
echo "================================================"
echo "🌍 يمكنك الآن الوصول إلى:"
echo "   • الواجهة الرئيسية: http://$(curl -s ifconfig.me)/"
echo "   • API الموحد: http://$(curl -s ifconfig.me)/api/"
echo "   • الذاكرة: http://$(curl -s ifconfig.me)/memory/"
echo "================================================"

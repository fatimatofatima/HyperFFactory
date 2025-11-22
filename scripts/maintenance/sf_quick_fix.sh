#!/bin/bash
echo "🔧 الإصلاح السريع لـ SmartFriend Suite"

# 1. إصلاح Nginx
echo "🌐 إصلاح Nginx..."
sudo rm -f /etc/nginx/sites-enabled/smartfriend*
sudo rm -f /etc/nginx/sites-available/smartfriend*

cat > /tmp/smartfriend-simple.conf << 'NGINX_EOF'
server {
    listen 80;
    server_name _;
    location / { proxy_pass http://127.0.0.1:8390/; }
    location /api/ { proxy_pass http://127.0.0.1:8220/; }
    location /memory/ { proxy_pass http://127.0.0.1:8214/; }
    location /health/ { proxy_pass http://127.0.0.1:8215/; }
    location /core/ { proxy_pass http://127.0.0.1:8383/; }
}
NGINX_EOF

sudo cp /tmp/smartfriend-simple.conf /etc/nginx/sites-available/smartfriend
sudo ln -sf /etc/nginx/sites-available/smartfriend /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 2. إصلاح الخدمات
echo "🔄 إصلاح الخدمات..."
sudo systemctl stop sf-memory.service sf-unified.service 2>/dev/null
sudo systemctl disable sf-memory.service sf-unified.service 2>/dev/null

sudo systemctl enable --now sf-memory-fixed.service
sudo systemctl enable --now sf-unified-fixed.service
sudo systemctl enable --now sf-core.service
sudo systemctl enable --now sf-web.service
sudo systemctl enable --now sf-health.service

sleep 5

# 3. العرض النهائي
echo ""
echo "✅ الإصلاح اكتمل!"
echo ""
echo "📊 الحالة النهائية:"
systemctl list-units "sf-*" --state=active --no-pager | grep -E "(active.*running)" | awk '{print "   ✅ " $1}'

echo ""
echo "🌐 اختبار الواجهات:"
curl -s http://127.0.0.1:8390/health >/dev/null && echo "   ✅ Web UI (8390)" || echo "   ❌ Web UI"
curl -s http://127.0.0.1:8220/health >/dev/null && echo "   ✅ Unified API (8220)" || echo "   ❌ Unified API" 
curl -s http://127.0.0.1:8214/ >/dev/null && echo "   ✅ Memory API (8214)" || echo "   ❌ Memory API"

echo ""
echo "🎯 يمكنك الآن الوصول إلى:"
echo "   http://$(curl -s ifconfig.me)/"
echo "   http://$(curl -s ifconfig.me)/api/"
echo "   http://$(curl -s ifconfig.me)/memory/"

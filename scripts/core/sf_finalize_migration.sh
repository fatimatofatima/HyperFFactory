#!/bin/bash
echo "============================================================"
echo "            التثبيت النهائي - إيقاف الليجاسي"
echo "============================================================"

# 1. نوقف عمليات الليجاسي
echo "🛑 إيقاف عمليات smartfrind الليجاسي..."
pkill -f "enhanced_unified_gateway_fixed.py" 2>/dev/null || true
pkill -f "smartfrind_bot.py" 2>/dev/null || true
pkill -f "main_bot.py" 2>/dev/null || true

# 2. نوقف خدمات systemd الليجاسي
echo "🛑 إيقاف خدمات smartfrind-*..."
systemctl stop smartfrind-* 2>/dev/null || true
systemctl disable smartfrind-* 2>/dev/null || true

# 3. نثبت Nginx النهائي
echo "🔀 تثبيت Nginx النهائي..."
cat > /etc/nginx/sites-enabled/smartfriend.conf <<'NGINX'
server {
    listen 80;
    server_name _;
    
    # Dashboard
    location /dashboard/ {
        proxy_pass http://127.0.0.1:8390/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Memory API
    location /memory/ {
        proxy_pass http://127.0.0.1:8214/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Unified API
    location /api/ {
        proxy_pass http://127.0.0.1:8220/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Core API
    location /core/ {
        proxy_pass http://127.0.0.1:8383/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Health
    location /health/ {
        proxy_pass http://127.0.0.1:8090/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # FFactory (نتركه كما هو)
    location /ffactory/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINX

# 4. نختبر ونشغل
nginx -t && systemctl reload nginx

echo "✅ تم التثبيت النهائي"
echo "🌐 المسارات النهائية:"
echo "   • http://your-server/dashboard/     ← Web UI"
echo "   • http://your-server/memory/        ← Memory API"  
echo "   • http://your-server/api/           ← Unified API"
echo "   • http://your-server/core/          ← Core API"
echo "   • http://your-server/health/        ← Health Check"

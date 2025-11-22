#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}" >&2; }

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/sf_publish_all_${TS}.log"

echo "=========================================="
echo "   🚀 SmartFriend Stack - Publish All v2.0"
echo "=========================================="
echo

log "بدء تحديث وتفعيل النظام المتكامل"
log "LOG_FILE: $LOG_FILE"

# ==========================================
# 1. تحديث جميع الريبوهات
# ==========================================
echo "=== 📦 تحديث الريبوهات ==="

update_repo() {
    local name="$1"
    local path="$2"
    
    log "معالجة: $name → $path"
    
    if [ ! -d "$path" ]; then
        warn "المسار $path غير موجود - تخطي"
        return 1
    fi
    
    cd "$path"
    
    if [ -d ".git" ]; then
        log "تحديث الريبو الموجود: $name"
        git fetch --all
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || git pull origin main
        log "✅ تم تحديث $name"
    else
        warn "المسار $path موجود لكنه ليس git repo - تخطي"
    fi
}

update_repo "smartfriend-complete-system" "/opt/smartfriend-complete-system"
update_repo "smartfriend-suite" "/opt/smartfriend-suite"
update_repo "ffactory" "/opt/ffactory"
update_repo "smartfrind-repo" "/opt/smartfrind-repo"

# ==========================================
# 2. تفعيل FFactory Stack
# ==========================================
echo
echo "=== 🏭 تفعيل FFactory Stack ==="

log "إعداد environment لـ FFactory..."
/root/ffactory_docker_tool.sh doctor

log "تشغيل FFactory Stack..."
/root/ffactory_docker_tool.sh down
/root/ffactory_docker_tool.sh up

sleep 5
log "فحص حالة FFactory:"
/root/ffactory_docker_tool.sh ps

# ==========================================
# 3. تفعيل SmartFrind Learning System
# ==========================================
echo
echo "=== 🤖 تفعيل SmartFrind Learning ==="

if [ -f "/root/smartfrind_activator.sh" ]; then
    /root/smartfrind_activator.sh
else
    warn "سكربت تفعيل SmartFrind غير موجود"
fi

# ==========================================
# 4. تفعيل النظام الهجين
# ==========================================
echo
echo "=== 🔄 تفعيل النظام الهجين ==="

log "تشغيل Hybrid API على port 8383..."
systemctl daemon-reload
systemctl enable smartfriend-hybrid.service
systemctl start smartfriend-hybrid.service

sleep 3
if systemctl is-active smartfriend-hybrid.service >/dev/null; then
    log "✅ Hybrid API نشط على port 8383"
else
    warn "⚠️  Hybrid API غير نشط - تشغيل يدوي..."
    cd /opt/smartfriend-suite
    nohup python3 -m uvicorn apps.unified.hybrid_api:app --host 0.0.0.0 --port 8383 > /var/log/hybrid_api.log 2>&1 &
fi

# ==========================================
# 5. تحديث Nginx Configuration
# ==========================================
echo
echo "=== 🌐 تحديث Nginx ==="

if [ -f "/root/sf_nginx_smartstack.sh" ]; then
    log "تحديث إعدادات Nginx ليشمل Hybrid API..."
    /root/sf_nginx_smartstack.sh 62.171.172.105
else
    warn "سكربت Nginx غير موجود"
fi

# ==========================================
# 6. الفحص النهائي الشامل
# ==========================================
echo
echo "=== 🔍 الفحص النهائي الشامل ==="

log "فحص جميع الخدمات:"

services=(
    "Smart Core:uvicorn.*smart_core.app:app:8211"
    "Unified API:uvicorn.*apps.unified.unified_api:app:8220"
    "Memory API:uvicorn.*memory_api.app:app:8214" 
    "Hybrid API:uvicorn.*apps.unified.hybrid_api:app:8383"
    "FFactory Main:python.*ffactory:8000"
    "SmartFrind:smartfrind:"
    "Nginx:nginx:80"
)

for service in "${services[@]}"; do
    IFS=':' read name pattern port <<< "$service"
    if pgrep -f "$pattern" >/dev/null; then
        echo -e "  ✅ $name - نشط"
        if [ -n "$port" ]; then
            if curl -s http://127.0.0.1:$port/ >/dev/null 2>&1; then
                echo -e "      🌐 HTTP متجاوب على port $port"
            else
                echo -e "      ⚠️  Port $port مشغول لكن غير متجاوب"
            fi
        fi
    else
        echo -e "  ❌ $name - غير نشط"
    fi
done

echo
log "فحص الحاويات:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
log "فحص خدمات systemd:"
systemctl is-active smartfrind-learning.service >/dev/null && echo "  ✅ smartfrind-learning.service - نشط" || echo "  ❌ smartfrind-learning.service - غير نشط"
systemctl is-active smartfriend-hybrid.service >/dev/null && echo "  ✅ smartfriend-hybrid.service - نشط" || echo "  ❌ smartfriend-hybrid.service - غير نشط"

echo
echo "=========================================="
echo "   ✅ تم التحديث والتفعيل الشامل بنجاح!"
echo "=========================================="
echo
echo "🌐 الواجهات المتاحة:"
echo "   • الموقع الرئيسي: http://62.171.172.105/"
echo "   • Smart Core: http://62.171.172.105/core/health" 
echo "   • Unified API: http://62.171.172.105/api/health"
echo "   • Hybrid API: http://62.171.172.105:8383"
echo "   • FFactory: http://62.171.172.105/ffactory/"
echo
echo "🔧 أنظمة التعلم:"
echo "   • SmartFrind Learning - نشط (systemd + cron)"
echo "   • Continuous Spider - مجدول يومياً"
echo
log "تفاصيل التنفيذ في: $LOG_FILE"

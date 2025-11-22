#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# 🚀 SmartFriend Stack - Quick Status Check
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
info()  { echo -e "${BLUE}[i]${NC} $*"; }

echo
echo "=========================================="
echo "   🚀 SmartFriend Stack - Quick Status"
echo "=========================================="
echo

# 1) فحص الخدمات الأساسية
info "1. فحص الخدمات الأساسية:"
services=(
  "8000:FFactory Main"
  "8170:FFactory Gateway" 
  "8211:Smart Core API"
  "8214:Memory API"
  "8220:Unified API"
  "11434:Ollama"
  "5432:PostgreSQL"
)

for service in "${services[@]}"; do
  port="${service%%:*}"
  name="${service#*:}"
  if ss -tln | grep -q ":${port} "; then
    log "$name - نشط (port $port)"
  else
    error "$name - غير نشط (port $port)"
  fi
done

# 2) فحص Nginx
echo
info "2. فحص Nginx Gateway:"
if systemctl is-active --quiet nginx; then
  log "Nginx - نشط"
  if curl -s http://localhost/nginx-health >/dev/null 2>&1; then
    log "  Health Check - OK"
  else
    warn "  Health Check - فشل"
  fi
else
  error "Nginx - غير نشط"
fi

# 3) فحص العمليات
echo
info "3. فحص العمليات النشطة:"
processes=(
  "smart_core.app:app:Smart Core"
  "apps.unified.unified_api:app:Unified API"
  "apps.memory_api:app:Memory API"
  "factory.gateway:app:FFactory Gateway"
)

for process in "${processes[@]}"; do
  pattern="${process%%:*}"
  name="${process#*:}"
  if pgrep -f "$pattern" >/dev/null; then
    pid=$(pgrep -f "$pattern")
    log "$name - نشط (PID: $pid)"
  else
    error "$name - غير نشط"
  fi
done

# 4) فحص المسارات
echo
info "4. فحص الهيكل الأساسي:"
paths=(
  "/opt/smartfriend-suite:SmartFriend Suite"
  "/opt/ffactory:FFactory"
  "/opt/smartfrind:SmartFrind"
  "/opt/smartfriend-suite/ENV/identity.env:ملف الهوية"
)

for path in "${paths[@]}"; do
  p="${path%%:*}"
  name="${path#*:}"
  if [ -e "$p" ]; then
    log "$name - موجود"
  else
    warn "$name - غير موجود"
  fi
done

# 5) فحص الأوامر
echo
info "5. فحص أدوات الإدارة:"
commands=(
  "smartfriend:أمر CLI"
  "nginx:Reverse Proxy"
  "git:Version Control"
)

for cmd in "${commands[@]}"; do
  name="${cmd%%:*}"
  desc="${cmd#*:}"
  if command -v "$name" >/dev/null 2>&1; then
    log "$desc - متوفر"
  else
    warn "$desc - غير متوفر"
  fi
done

# 6) فحص سريع للتواصل الخارجي
echo
info "6. فحص الاتصالات الخارجية:"
if curl -s --connect-timeout 5 https://api.groq.com >/dev/null 2>&1; then
  log "Groq API - متصل"
else
  warn "Groq API - غير متصل"
fi

if curl -s --connect-timeout 5 https://api.telegram.org >/dev/null 2>&1; then
  log "Telegram API - متصل"
else
  warn "Telegram API - غير متصل"
fi

# 7) فحص الموارد
echo
info "7. فحص موارد النظام:"
echo "   💾 الذاكرة: $(free -h | awk '/Mem:/ {print $3 "/" $2 " (" $3/$2*100 "%)"}')"
echo "   🖥️  الحمل: $(uptime | awk -F'load average:' '{print $2}')"
echo "   💿 التخزين: $(df -h / | awk 'NR==2{print $4 " free / " $2 " total (" $5 " used)"}')"

# 8) روابط سريعة للاختبار
echo
info "8. روابط سريعة للاختبار:"
echo "   🌐 الواجهة: curl http://62.171.172.105/"
echo "   🤖 Core API: curl http://62.171.172.105/core/health"
echo "   🏭 FFactory: curl http://62.171.172.105/ffactory/"
echo "   ❤️  Health: curl http://62.171.172.105/nginx-health"

echo
echo "=========================================="
echo "   ✅ الفحص اكتمل - $(date)"
echo "=========================================="
echo

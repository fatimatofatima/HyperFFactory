#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[⚠] $*${NC}"; }
error() { echo -e "${RED}[❌] $*${NC}"; }
info()  { echo -e "${BLUE}[ℹ] $*${NC}"; }
debug() { echo -e "${CYAN}[🐛] $*${NC}"; }

echo "================================================================"
echo "   🔍 SmartFriend System - Comprehensive Analyzer"
echo "================================================================"
echo

# ==========================================
# 1. فحص النظام الأساسي
# ==========================================
echo "=== 🔧 النظام الأساسي ==="
echo "🖥️  Hostname: $(hostname)"
echo "📦 OS: $(lsb_release -d | cut -f2)"
echo "💾 Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "🖥️  Load: $(uptime | awk -F'load average:' '{print $2}')"
echo

# ==========================================
# 2. فحص الريبوهات والمجلدات
# ==========================================
echo "=== 📁 الريبوهات والمجلدات ==="
check_repo() {
    local name="$1"
    local path="$2"
    
    if [ -d "$path" ]; then
        if [ -d "$path/.git" ]; then
            local branch=$(cd "$path" && git branch --show-current 2>/dev/null || echo "unknown")
            local commit=$(cd "$path" && git log -1 --format="%h" 2>/dev/null || echo "unknown")
            echo -e "  ✅ $name - موجود (branch: $branch, commit: $commit)"
        else
            echo -e "  ⚠️  $name - موجود لكن ليس git repo"
        fi
    else
        echo -e "  ❌ $name - غير موجود"
    fi
}

check_repo "smartfriend-complete-system" "/opt/smartfriend-complete-system"
check_repo "smartfriend-suite" "/opt/smartfriend-suite"
check_repo "ffactory" "/opt/ffactory"
check_repo "smartfrind" "/opt/smartfrind"
echo

# ==========================================
# 3. فحص الخدمات والعمليات
# ==========================================
echo "=== 🚀 الخدمات النشطة ==="
check_process() {
    local name="$1"
    local pattern="$2"
    local port="$3"
    
    local pids=$(pgrep -f "$pattern" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
    if [ -n "$pids" ]; then
        echo -e "  ✅ $name - نشط (PIDs: $pids)"
        if [ -n "$port" ]; then
            if ss -tln | grep -q ":$port "; then
                echo -e "      📍 Port $port متاح"
                # Test connectivity
                if timeout 2 curl -s http://localhost:$port/ >/dev/null 2>&1; then
                    echo -e "      🌐 HTTP متجاوب على port $port"
                fi
            else
                echo -e "      ⚠️  Port $port غير متاح"
            fi
        fi
    else
        echo -e "  ❌ $name - غير نشط"
    fi
}

check_process "Smart Core" "uvicorn.*smart_core.app:app" "8211"
check_process "Unified API" "uvicorn.*apps.unified.unified_api:app" "8220"
check_process "Memory API" "uvicorn.*memory_api.app:app" "8214"
check_process "FFactory Main" "python.*ffactory\|:8000" "8000"
check_process "FFactory Gateway" ".*ffactory.*gateway\|:8170" "8170"
check_process "SmartFrind Legacy" "smartfrind" ""
echo

# ==========================================
# 4. فحص systemd Services
# ==========================================
echo "=== ⚙️  خدمات Systemd ==="
check_systemd_service() {
    local service="$1"
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo -e "  ✅ $service - نشط"
    elif systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo -e "  ⚠️  $service - معطل لكن مُمكن"
    else
        echo -e "  ❌ $service - غير نشط/غير موجود"
    fi
}

check_systemd_service "smartfriend-smartcore.service"
check_systemd_service "smartfriend-unified.service"
check_systemd_service "nginx.service"
echo

# ==========================================
# 5. فحص Nginx والمنافذ
# ==========================================
echo "=== 🌐 شبكة ومنافذ ==="
echo "📡 المنافذ المشغولة:"
ss -tlnp | grep -E ':(80|8000|8211|8220|8170)' | while read line; do
    echo "  $line"
done

echo
echo "🔗 فحص Nginx:"
if systemctl is-active nginx >/dev/null 2>&1; then
    echo -e "  ✅ Nginx - نشط"
    # Test Nginx endpoints
    endpoints=("/nginx-health" "/core/health" "/ffactory/" "/")
    for endpoint in "${endpoints[@]}"; do
        if timeout 3 curl -s http://localhost$endpoint >/dev/null 2>&1; then
            echo -e "      ✅ $endpoint - متجاوب"
        else
            echo -e "      ❌ $endpoint - غير متجاوب"
        fi
    done
else
    echo -e "  ❌ Nginx - غير نشط"
fi
echo

# ==========================================
# 6. فحص Docker (لـ FFactory)
# ==========================================
echo "=== 🐳 Docker Services ==="
if command -v docker >/dev/null 2>&1; then
    echo -e "  ✅ Docker - مثبت"
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | grep -v "NAMES"; then
        echo "      الحاويات النشطة:"
        docker ps --format "        🐳 {{.Names}} - {{.Status}} - {{.Ports}}"
    else
        echo -e "      ⚠️  لا توجد حاويات نشطة"
    fi
else
    echo -e "  ❌ Docker - غير مثبت"
fi
echo

# ==========================================
# 7. فحص السكربتات المتاحة
# ==========================================
echo "=== 📜 السكربتات المتاحة ==="
scripts=(
    "/root/ffactory_stack.sh"
    "/root/sf_nginx_smartstack.sh" 
    "/root/sf_publish_all.sh"
    "/root/sf_fix_nginx_ffhealthd.sh"
    "/usr/local/bin/smartfriend"
)

for script in "${scripts[@]}"; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        echo -e "  ✅ $(basename $script) - موجود وقابل للتنفيذ"
    elif [ -f "$script" ]; then
        echo -e "  ⚠️  $(basename $script) - موجود لكن غير قابل للتنفيذ"
    else
        echo -e "  ❌ $(basename $script) - غير موجود"
    fi
done
echo

# ==========================================
# 8. التوصيات
# ==========================================
echo "=== 💡 التوصيات ==="
if ! systemctl is-active nginx >/dev/null 2>&1; then
    echo "  🔧 تشغيل Nginx: systemctl start nginx"
fi

if ! pgrep -f "uvicorn.*smart_core.app:app" >/dev/null 2>&1; then
    echo "  🔧 إعادة تشغيل Smart Core"
fi

if [ ! -d "/opt/smartfriend-complete-system" ]; then
    echo "  🔧 استكمال تنزيل smartfriend-complete-system"
fi

echo
echo "================================================================"
echo "   ✅ انتهى الفحص - $(date)"
echo "================================================================"

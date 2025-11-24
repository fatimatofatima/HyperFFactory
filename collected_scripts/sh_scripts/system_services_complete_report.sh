#!/usr/bin/env bash
set -Eeuo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; }

echo "=================================================="
echo "           📊 تقرير شامل لخدمات النظام"
echo "=================================================="
echo

# 1) معلومات النظام الأساسية
log "معلومات النظام الأساسية:"
echo "👤 المستخدم: $(whoami)"
echo "🖥️  السيرفر: $(hostname)"
echo "📟 نظام التشغيل: $(lsb_release -d | cut -f2)"
echo "🐧 النواة: $(uname -r)"
echo "⏰ وقت التشغيل: $(uptime -p)"
echo

# 2) جميع خدمات systemd مع تفاصيل كاملة
log "جميع خدمات systemd مصنفة:"
echo "--------------------------------------------------"

# خدمات SmartFriend Suite
echo "🎯 SmartFriend Suite Services:"
systemctl list-units 'sf-*' 'smartfriend-*' --all --no-legend | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    if [[ "$active" == "active" ]]; then
        echo "  ✅ $unit - $desc"
        echo "      📍 الموقع: ${unit_file:-غير معروف}"
        echo "      🟢 الحالة: $active ($sub)"
    else
        echo "  ❌ $unit - $desc"
        echo "      📍 الموقع: ${unit_file:-غير معروف}"
        echo "      🔴 الحالة: $active ($sub)"
    fi
done
echo

# خدمات ffactory
echo "🏭 FFactory Services:"
systemctl list-units 'ff*' 'factory-*' --all --no-legend | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    if [[ "$active" == "active" ]]; then
        echo "  ✅ $unit - $desc"
        echo "      📍 الموقع: ${unit_file:-غير معروف}"
        echo "      🟢 الحالة: $active ($sub)"
    else
        echo "  ❌ $unit - $desc"
        echo "      📍 الموقع: ${unit_file:-غير معروف}"
        echo "      🔴 الحالة: $active ($sub)"
    fi
done
echo

# خدمات النظام الأساسية
echo "⚙️  خدمات النظام الأساسية:"
important_services=(
    "nginx" "postgresql" "docker" "redis" "mongod" 
    "mysql" "apache2" "ssh" "cron" "systemd-journald"
)
for service in "${important_services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        unit_file=$(systemctl show -p FragmentPath "$service" 2>/dev/null | cut -d= -f2)
        echo "  ✅ $service - شغال"
        echo "      📍 الموقع: ${unit_file:-غير معروف}"
    fi
done
echo

# 3) تحليل استخدام الموارد
log "تحليل استخدام موارد النظام:"
echo "💾 الذاكرة:"
free -h | awk 'NR==2{printf "      الاستخدام: %s/%s (%.1f%%)\n", $3, $2, $3/$2*100}'
echo "💿 التخزين:"
df -h / | awk 'NR==2{printf "      الاستخدام: %s/%s (%s)\n", $3, $2, $5}'
echo "🔥 الحمل:"
uptime | awk -F'load average:' '{print "      " $2}'
echo

# 4) المنافذ النشطة
log "المنافذ النشطة والخدمات المرتبطة بها:"
echo "🌐 المنافذ النشطة:"
netstat -tlnp | awk '/LISTEN/ {
    split($4, addr, ":")
    port = addr[length(addr)]
    split($7, proc, "/")
    name = proc[2]
    pid = proc[1]
    if(port ~ /^(80|443|22|53|3306|5432|6379|27017|8080|8383|8170|8210|8220)/)
        printf "      📍 Port %s -> %s (PID: %s)\n", port, name, pid
}' | sort -k3 -n
echo

# 5) خدمات مخصصة من المستخدم
log "الخدمات المخصصة في /etc/systemd/system:"
echo "📁 الخدمات المخصصة:"
find /etc/systemd/system -name "*.service" -type f | while read service; do
    service_name=$(basename "$service")
    if systemctl is-active "$service_name" >/dev/null 2>&1; then
        echo "  ✅ $service_name - $(grep Description "$service" | cut -d= -f2)"
        echo "      📍 الموقع: $service"
    fi
done
echo

# 6) ملخص إحصائي
log "ملخص إحصائي للخدمات:"
total_services=$(systemctl list-units --all | wc -l)
active_services=$(systemctl list-units --state=active | wc -l)
failed_services=$(systemctl list-units --state=failed | wc -l)

echo "📈 الإحصائيات:"
echo "      إجمالي الخدمات: $((total_services - 1))"
echo "      الخدمات النشطة: $((active_services - 1))"
echo "      الخدمات الفاشلة: $((failed_services - 1))"
echo

# 7) التحقق من الصحة
log "التحقق من صحة الخدمات الحرجة:"
critical_services=("nginx" "postgresql" "docker" "ssh")
for service in "${critical_services[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "$service - يعمل بشكل طبيعي"
    else
        error "$service - غير نشط أو به مشكلة"
    fi
done

echo
echo "=================================================="
success "تم إنشاء التقرير الشامل لخدمات النظام"
echo "=================================================="

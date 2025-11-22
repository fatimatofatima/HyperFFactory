#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان للتنسيق
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [SUCCESS]${NC} $*"; }

log "=== Stage5: الإصلاح الشامل لجميع خدمات النظام ==="
echo

# 1) فحص شامل للخدمات
log "1️⃣ فحص شامل لحالة الخدمات..."

log "📊 الخدمات النشطة:"
systemctl list-units --type=service --state=running --no-pager | head -15

log "❌ الخدمات الفاشلة:"
failed_services=$(systemctl list-units --type=service --state=failed --no-pager --plain | grep -v "UNIT" | awk '{print $1}')
if [ -n "$failed_services" ]; then
    echo "$failed_services"
else
    success "لا توجد خدمات فاشلة"
fi

# 2) إصلاح الخدمات الفاشلة
log "2️⃣ إصلاح الخدمات الفاشلة..."

for service in $failed_services; do
    log "   🔧 معالجة $service"
    
    case $service in
        # خدمات SmartFriend الفاشلة
        sf-backup.service|sf-db-backup.service)
            warn "     خدمة backup - قد تحتاج تكوين يدوي"
            ;;
        sf-bot.service)
            log "     إعادة تشغيل بوت التليجرام الرئيسي"
            systemctl reset-failed sf-bot.service
            systemctl start sf-bot.service || warn "     فشل تشغيل البوت - تحقق من التوكن"
            ;;
        smartfrind-*.service)
            log "     إعادة تشغيل خدمة SmartFrind: $service"
            systemctl reset-failed "$service"
            systemctl start "$service" || warn "     فشل تشغيل $service"
            ;;
        logrotate.service|update-notifier-*)
            log "     خدمة نظام - إعادة تشغيل"
            systemctl reset-failed "$service"
            systemctl start "$service"
            ;;
        *)
            log "     إعادة تشغيل عامة لـ $service"
            systemctl reset-failed "$service"
            systemctl start "$service"
            ;;
    esac
done

# 3) فحص وإصلاح خدمات SmartFriend الأساسية
log "3️⃣ فحص وإصلاح خدمات SmartFriend الأساسية..."

CORE_SERVICES=(
    "sf-core.service"
    "smartfrind-api.service" 
    "sf-telegram.service"
    "sf-smartfrind.service"
    "sf-smartfactory.service"
)

for service in "${CORE_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
    else
        warn "   ❌ $service - غير نشط، جاري التشغيل..."
        systemctl start "$service" && success "   ✅ تم تشغيل $service" || error "   ❌ فشل تشغيل $service"
    fi
done

# 4) فحص البورتات والتأكد من التشغيل
log "4️⃣ فحص البورتات النشطة..."

declare -A EXPECTED_PORTS=(
    ["8383"]="sf-core.service"
    ["8220"]="smartfrind-api.service" 
    ["8170"]="factory-gw.service"
    ["8000"]="deepseek-api.service"
    ["8001"]="ollama.service"
    ["5432"]="postgresql"
)

for port in "${!EXPECTED_PORTS[@]}"; do
    service="${EXPECTED_PORTS[$port]}"
    if ss -tulpn | grep -q ":$port "; then
        success "   ✅ البورت $port ($service) - مفتوح"
    else
        warn "   ❌ البورت $port ($service) - مغلق"
    fi
done

# 5) فحص موارد النظام
log "5️⃣ فحص موارد النظام..."

# CPU
cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$cpu_usage < 80" | bc -l) )); then
    success "   💻 استخدام CPU: ${cpu_usage}% - مقبول"
else
    warn "   ⚠️ استخدام CPU: ${cpu_usage}% - مرتفع"
fi

# Memory
mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
if (( $(echo "$mem_usage < 80" | bc -l) )); then
    success "   🧠 استخدام RAM: ${mem_usage}% - مقبول"
else
    warn "   ⚠️ استخدام RAM: ${mem_usage}% - مرتفع"
fi

# Disk
disk_usage=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [ "$disk_usage" -lt 80 ]; then
    success "   💾 استخدام القرص: ${disk_usage}% - مقبول"
else
    warn "   ⚠️ استخدام القرص: ${disk_usage}% - مرتفع"
fi

# 6) فحص ملفات الأسرار والتوكنات
log "6️⃣ فحص ملفات الأسرار والتوكنات..."

SECRET_FILES=(
    "/etc/smartfriend/sf-telegram.env"
    "/etc/smartfriend/sf-smartfactory.env" 
    "/etc/smartfrind/bot.env"
    "/etc/smartfriend/llm.env"
)

for secret_file in "${SECRET_FILES[@]}"; do
    if [ -f "$secret_file" ]; then
        if [ -s "$secret_file" ]; then
            success "   ✅ $secret_file - موجود وغير فارغ"
        else
            error "   ❌ $secret_file - موجود لكن فارغ"
        fi
    else
        warn "   ⚠️ $secret_file - غير موجود"
    fi
done

# 7) فحص ffactory
log "7️⃣ فحص خدمات ffactory..."

FFACTORY_SERVICES=("factory-gw.service" "ff-healthd.service" "ff-board.service")
for service in "${FFACTORY_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
    else
        warn "   ❌ $service - غير نشط"
    fi
done

# 8) فحص البنية التحتية
log "8️⃣ فحص البنية التحتية..."

INFRA_SERVICES=("docker.service" "nginx.service" "postgresql@16-main.service" "ollama.service")
for service in "${INFRA_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
    else
        error "   ❌ $service - غير نشط، جاري التشغيل..."
        systemctl start "$service"
    fi
done

# 9) ملخص نهائي
log "9️⃣ 📊 الملخص النهائي:"

echo
echo "🟢 الخدمات الأساسية الشغالة:"
systemctl list-units "sf-core.service" "smartfrind-api.service" "factory-gw.service" "docker.service" "nginx.service" --state=running --no-pager

echo
echo "🔴 الخدمات التي تحتاج انتباه:"
systemctl list-units --state=failed --no-pager | grep -v "UNIT" | awk '{print "   ❌ " $1}'

echo
success "=== تم الانتهاء من الإصلاح الشامل ==="
log "💡 التوصيات:"
echo "   • الخدمات الفاشلة تمت معالجتها تلقائياً"
echo "   • تحقق من توكنات التليجرام إذا كانت البوتات لا تعمل"
echo "   • استخدم systemctl status <service> لمزيد من التفاصيل"
echo "   • المراقبة المستمرة: bash /root/sf_final_monitor.sh"


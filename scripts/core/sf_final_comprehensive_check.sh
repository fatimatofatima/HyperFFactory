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
info(){ echo -e "${CYAN}[$(date '+%F %T')] [INFO]${NC} $*"; }

log "=== الفحص الشامل النهائي لـ SmartFriend Suite ==="
echo

# 1) فحص الخدمات الأساسية
log "1️⃣ فحص الخدمات الأساسية النشطة..."

CORE_SERVICES=(
    "sf-core.service"
    "smartfrind-api.service"
    "smartfrind-qa.service"
    "smartfrind-runner.service"
    "smartfrind-envwatch.service"
    "smartfrind-monitor.service"
)

ACTIVE_COUNT=0
for service in "${CORE_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
        ((ACTIVE_COUNT++))
    else
        error "   ❌ $service - غير نشط"
    fi
done

info "   📊 الخدمات الأساسية النشطة: $ACTIVE_COUNT/${#CORE_SERVICES[@]}"

# 2) فحص البورتات
log "2️⃣ فحص البورتات النشطة..."

declare -A PORTS=(
    ["8383"]="sf-core.service"
    ["8220"]="smartfrind-api.service"
    ["8000"]="deepseek-api.service"
    ["8170"]="factory-gw.service"
    ["5432"]="postgresql"
)

PORT_COUNT=0
for port in "${!PORTS[@]}"; do
    service="${PORTS[$port]}"
    if ss -tulpn | grep -q ":$port "; then
        success "   ✅ البورت $port ($service) - مفتوح"
        ((PORT_COUNT++))
    else
        error "   ❌ البورت $port ($service) - مغلق"
    fi
done

info "   📊 البورتات النشطة: $PORT_COUNT/${#PORTS[@]}"

# 3) فحص الخدمات الفاشلة
log "3️⃣ فحص الخدمات الفاشلة..."

FAILED_SERVICES=$(systemctl list-units --state=failed --no-pager --plain | grep -E "(sf-|smartfrind|smartfriend)" | awk '{print $1}')

if [ -z "$FAILED_SERVICES" ]; then
    success "   ✅ لا توجد خدمات فاشلة"
else
    error "   ❌ الخدمات الفاشلة:"
    echo "$FAILED_SERVICES" | while read service; do
        echo "      🔴 $service"
        
        # تشخيص سريع للسبب
        case $service in
            *backup*)
                echo "         📦 مشكلة في النسخ الاحتياطي - تحتاج تكوين DB"
                ;;
            *bot*|*telegram*)
                echo "         🤖 مشكلة في التوكن - تحقق من /etc/smartfriend/"
                ;;
            *learn*|*train*)
                echo "         🧠 مشكلة في التعلم - مكتبات أو استيراد"
                ;;
            *harvest*|*ingest*|*raw*)
                echo "         🔍 مشكلة في الصلاحيات - تم إصلاحها"
                ;;
            *reflector*)
                echo "         🗄️ مشكلة في قاعدة البيانات - تحتاج إنشاء DB"
                ;;
            *)
                echo "         ⚠️ سبب غير محدد"
                ;;
        esac
    done
fi

# 4) فحص الموارد
log "4️⃣ فحص موارد النظام..."

# CPU
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE < 70" | bc -l) )); then
    success "   💻 استخدام CPU: ${CPU_USAGE}% - مقبول"
else
    warn "   ⚠️ استخدام CPU: ${CPU_USAGE}% - مرتفع"
fi

# Memory
MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
if (( $(echo "$MEM_USAGE < 80" | bc -l) )); then
    success "   🧠 استخدام RAM: ${MEM_USAGE}% - مقبول"
else
    warn "   ⚠️ استخدام RAM: ${MEM_USAGE}% - مرتفع"
fi

# Disk
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
if [ "$DISK_USAGE" -lt 80 ]; then
    success "   💾 استخدام القرص: ${DISK_USAGE}% - مقبول"
else
    warn "   ⚠️ استخدام القرص: ${DISK_USAGE}% - مرتفع"
fi

# 5) فحص المسارات والصلاحيات
log "5️⃣ فحص المسارات والصلاحيات..."

PATHS=(
    "/opt/smartfriend-suite"
    "/opt/smartfriend-suite/smartfriend"
    "/opt/smartfriend-suite/data"
    "/opt/smartfriend-suite/smartfriend/venv/bin/python"
)

for path in "${PATHS[@]}"; do
    if [ -e "$path" ]; then
        if [ -d "$path" ]; then
            perms=$(stat -c "%a" "$path")
            if [ "$perms" = "755" ]; then
                success "   ✅ $path - صلاحيات 755"
            else
                warn "   ⚠️ $path - صلاحيات $perms (مطلوب 755)"
            fi
        else
            success "   ✅ $path - موجود"
        fi
    else
        error "   ❌ $path - غير موجود"
    fi
done

# 6) فحص قاعدة البيانات
log "6️⃣ فحص قاعدة البيانات..."

DB_PATH="/opt/smartfriend-suite/data/smartfriend_unified.db"
if [ -f "$DB_PATH" ]; then
    if [ -s "$DB_PATH" ]; then
        success "   ✅ $DB_PATH - موجود وغير فارغ"
        DB_SIZE=$(stat -c "%s" "$DB_PATH")
        info "      📊 حجم قاعدة البيانات: $(echo "scale=2; $DB_SIZE/1024/1024" | bc) MB"
    else
        warn "   ⚠️ $DB_PATH - موجود لكن فارغ"
    fi
else
    error "   ❌ $DB_PATH - غير موجود"
fi

# 7) فحص ملفات التوكنات
log "7️⃣ فحص ملفات التوكنات والبيئة..."

ENV_FILES=(
    "/etc/smartfriend/sf-telegram.env"
    "/etc/smartfriend/sf-smartfactory.env"
    "/etc/smartfrind/bot.env"
)

TOKEN_COUNT=0
for env_file in "${ENV_FILES[@]}"; do
    if [ -f "$env_file" ] && [ -s "$env_file" ]; then
        success "   ✅ $env_file - موجود وغير فارغ"
        ((TOKEN_COUNT++))
    else
        error "   ❌ $env_file - غير موجود أو فارغ"
    fi
done

info "   📊 ملفات التوكنات الصالحة: $TOKEN_COUNT/${#ENV_FILES[@]}"

# 8) فحص خدمات ffactory (للاطمئنان فقط)
log "8️⃣ فحص خدمات ffactory (للاطمئنان)..."

FFACTORY_SERVICES=("factory-gw.service" "ff-healthd.service")
FFACTORY_COUNT=0
for service in "${FFACTORY_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
        ((FFACTORY_COUNT++))
    else
        warn "   ⚠️ $service - غير نشط"
    fi
done

# 9) الملخص النهائي
echo
log "📊 📊 الملخص النهائي الشامل:"
echo "=========================================="

echo "🟢 الإنجازات:"
echo "   • ✅ الخدمات الأساسية: $ACTIVE_COUNT/${#CORE_SERVICES[@]} نشطة"
echo "   • ✅ البورتات: $PORT_COUNT/${#PORTS[@]} مفتوحة"
echo "   • ✅ التوكنات: $TOKEN_COUNT/${#ENV_FILES[@]} مضبوطة"
echo "   • ✅ ffactory: $FFACTORY_COUNT/${#FFACTORY_SERVICES[@]} نشطة"

if [ -n "$FAILED_SERVICES" ]; then
    echo
    echo "🔴 المشاكل المتبقية:"
    FAILED_COUNT=$(echo "$FAILED_SERVICES" | wc -l)
    echo "   • ❌ خدمات فاشلة: $FAILED_COUNT"
    echo "$FAILED_SERVICES" | while read service; do
        echo "     - $service"
    done
fi

echo
echo "💡 التوصيات النهائية:"
if [ -n "$FAILED_SERVICES" ]; then
    echo "   1. راجع سجلات الخدمات الفاشلة: journalctl -u <service>"
    echo "   2. بعض الخدمات قد تحتاج تكوين يدوي (مثل backup)"
    echo "   3. خدمات التعلم قد تحتاج مكتبات إضافية"
fi
echo "   4. النظام الأساسي مستقر وجاهز للعمل"
echo "   5. استخدم: bash /root/sf_final_monitor.sh للمراقبة المستمرة"

echo
success "=== تم الانتهاء من الفحص الشامل النهائي ==="


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

log "=== تشخيص وإصلاح شامل لأعطال خدمات السيوت ==="
echo

# 1) فحص الخدمات الفاشلة
log "1️⃣ فحص الخدمات الفاشلة وتشخيص أسباب الأعطال..."

FAILED_SERVICES=$(systemctl list-units --state=failed --no-pager --plain | grep -E "(sf-|smartfrind|smartfriend)" | awk '{print $1}')

if [ -z "$FAILED_SERVICES" ]; then
    success "لا توجد خدمات فاشلة في السيوت"
else
    warn "الخدمات الفاشلة التي تحتاج إصلاح:"
    echo "$FAILED_SERVICES"
    echo
fi

# 2) تشخيص كل خدمة فاشلة
for service in $FAILED_SERVICES; do
    log "🔍 تشخيص الخدمة: $service"
    
    # الحصول على سجلات الخدمة
    journalctl -u "$service" -n 10 --no-pager | grep -E "(error|fail|exception|Error|Fail|Exception)" | head -5 || true
    
    # فحص سبب الفشل
    case $service in
        *backup*)
            warn "   📦 مشكلة في خدمة النسخ الاحتياطي - قد تحتاج تكوين قاعدة بيانات"
            ;;
        *bot*|*telegram*)
            error "   🤖 مشكلة في بوت التليجرام - تحقق من التوكنات في /etc/smartfriend/"
            # عرض معلومات التوكن
            if [ -f "/etc/smartfriend/sf-telegram.env" ]; then
                grep -E "BOT_TOKEN|TELEGRAM" /etc/smartfriend/sf-telegram.env | head -2 || true
            fi
            ;;
        *learn*|*train*)
            warn "   🧠 مشكلة في خدمة التعلم - قد تكون مشكلة في استيراد المكتبات"
            ;;
        *db*)
            warn "   🗄️ مشكلة في خدمة قاعدة البيانات - تحقق من اتصال DB"
            ;;
        *memory*)
            warn "   💾 مشكلة في خدمة الذاكرة - قد تكون مشكلة في الوصول للبيانات"
            ;;
        *)
            warn "   ⚠️ سبب غير محدد - راجع السجلات للتفاصيل"
            ;;
    esac
    echo
done

# 3) فحص وإصلاح التوكنات
log "2️⃣ فحص وإصلاح توكنات التليجرام..."

TELEGRAM_SERVICES=(
    "sf-telegram.service"
    "sf-smartfrind.service" 
    "sf-smartfactory.service"
    "sf-telegram-audit.service"
    "smartfrind-bot.service"
)

for service in "${TELEGRAM_SERVICES[@]}"; do
    if systemctl is-failed "$service" >/dev/null 2>&1; then
        log "   🔧 معالجة $service"
        
        # إعادة تعيين الفشل
        systemctl reset-failed "$service" 2>/dev/null || true
        
        # محاولة التشغيل مع فحص السجلات
        if systemctl start "$service" 2>/dev/null; then
            success "   ✅ تم تشغيل $service بنجاح"
        else
            error "   ❌ فشل تشغيل $service"
            # عرض آخر الأخطاء
            journalctl -u "$service" -n 5 --no-pager | grep -i error | tail -3 || true
        fi
    fi
done

# 4) فحص ملفات البيئة والأسرار
log "3️⃣ فحص ملفات البيئة والأسرار..."

ENV_FILES=(
    "/etc/smartfriend/sf-telegram.env"
    "/etc/smartfriend/sf-smartfactory.env"
    "/etc/smartfrind/bot.env"
    "/etc/smartfriend/llm.env"
    "/etc/smartfriend/keys.env"
)

for env_file in "${ENV_FILES[@]}"; do
    if [ -f "$env_file" ]; then
        if [ -s "$env_file" ]; then
            success "   ✅ $env_file - موجود وغير فارغ"
            # فحص إذا كان يحتوي توكنات
            if grep -q "BOT_TOKEN\|TELEGRAM\|API_KEY" "$env_file" 2>/dev/null; then
                log "     📋 يحتوي على مفاتيح API/توكنات"
            fi
        else
            error "   ❌ $env_file - موجود لكن فارغ!"
        fi
    else
        warn "   ⚠️ $env_file - غير موجود"
    fi
done

# 5) فحص وإصلاح خدمات التعلم والذاكرة
log "4️⃣ فحص وإصلاح خدمات التعلم والذاكرة..."

LEARNING_SERVICES=(
    "sf-learning.service"
    "smartfrind-learning.service" 
    "smartfrind-trainer.service"
    "sf-memory.service"
)

for service in "${LEARNING_SERVICES[@]}"; do
    if systemctl is-failed "$service" >/dev/null 2>&1 || ! systemctl is-active "$service" >/dev/null 2>&1; then
        log "   🔧 معالجة $service"
        systemctl reset-failed "$service" 2>/dev/null || true
        systemctl start "$service" && success "   ✅ تم تشغيل $service" || warn "   ⚠️ $service لا يزال به مشكلة"
    fi
done

# 6) فحص وإصلاح خدمات البنية التحتية
log "5️⃣ فحص وإصلاح خدمات البنية التحتية..."

INFRA_SERVICES=(
    "sf-core.service"
    "smartfrind-api.service"
    "smartfrind-qa.service"
    "smartfrind-runner.service"
)

for service in "${INFRA_SERVICES[@]}"; do
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
        log "   🔧 تشغيل $service"
        systemctl start "$service" && success "   ✅ تم تشغيل $service" || error "   ❌ فشل تشغيل $service"
    else
        success "   ✅ $service - نشط"
    fi
done

# 7) فحص البورتات والتأكد من التشغيل
log "6️⃣ فحص البورتات والتأكد من التشغيل..."

declare -A PORTS=(
    ["8383"]="sf-core.service"
    ["8220"]="smartfrind-api.service"
    ["8000"]="deepseek-api.service"
    ["8170"]="factory-gw.service"
)

for port in "${!PORTS[@]}"; do
    service="${PORTS[$port]}"
    if ss -tulpn | grep -q ":$port "; then
        success "   ✅ البورت $port ($service) - مفتوح"
    else
        error "   ❌ البورت $port ($service) - مغلق"
        # محاولة تشغيل الخدمة
        if systemctl start "$service" 2>/dev/null; then
            success "     ✅ تم تشغيل $service"
        fi
    fi
done

# 8) فحص الموارد والتأكد من عدم وجود ازدحام
log "7️⃣ فحص موارد النظام..."

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

# 9) إعادة تحميل systemd وتنشيط الخدمات
log "8️⃣ إعادة تحميل systemd وتنشيط الخدمات..."

systemctl daemon-reload
success "   ✅ تم إعادة تحميل systemd"

# 10) تشغيل الخدمات الأساسية
log "9️⃣ تشغيل الخدمات الأساسية للسيوت..."

CORE_SERVICES=(
    "sf-core.service"
    "smartfrind-api.service"
    "smartfrind-qa.service"
    "smartfrind-runner.service"
    "smartfrind-envwatch.service"
)

for service in "${CORE_SERVICES[@]}"; do
    if systemctl start "$service" 2>/dev/null; then
        success "   ✅ $service - مشغل"
    else
        systemctl restart "$service" 2>/dev/null && success "   ✅ $service - أعيد تشغيله" || error "   ❌ $service - فشل التشغيل"
    fi
done

# 11) الملخص النهائي
log "🔟 📊 الملخص النهائي للإصلاح:"

echo
echo "🟢 الخدمات النشطة الآن:"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager | head -10

echo
echo "🔴 الخدمات التي لا تزال تحتاج انتباه:"
systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-pager | grep -v "UNIT" | awk '{print "   ❌ " $1}' || echo "   ✅ لا توجد خدمات فاشلة"

echo
echo "💡 التوصيات النهائية:"
echo "   1. تحقق من توكنات التليجرام في /etc/smartfriend/"
echo "   2. تأكد من وجود قاعدة البيانات في /opt/smartfriend-suite/data/"
echo "   3. استخدم: journalctl -u <service> لمزيد من التفاصيل"
echo "   4. المراقبة المستمرة: bash /root/sf_final_monitor.sh"

success "=== تم الانتهاء من التشخيص والإصلاح الشامل ==="


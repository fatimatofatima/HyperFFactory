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

log "=== فحص شامل لجميع خدمات النظام ==="
echo

# 1) جميع الخدمات النشطة
log "1️⃣ جميع الخدمات النشطة على النظام:"
systemctl list-units --type=service --state=running --no-pager | head -20
echo

# 2) الخدمات الفاشلة
log "2️⃣ الخدمات الفاشلة:"
systemctl list-units --type=service --state=failed --no-pager
echo

# 3) خدمات SmartFriend/SmartFrind فقط
log "3️⃣ خدمات SmartFriend/SmartFrind:"
systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --all --no-pager
echo

# 4) خدمات ffactory/factory فقط
log "4️⃣ خدمات ffactory/factory:"
systemctl list-units "ff-*" "ffactory*" "factory-*" --all --no-pager
echo

# 5) خدمات البنية التحتية
log "5️⃣ خدمات البنية التحتية:"
systemctl list-units "postgresql*" "docker*" "nginx*" "ollama*" "redis*" "mysql*" --all --no-pager
echo

# 6) إحصائيات الخدمات
log "6️⃣ إحصائيات الخدمات:"

ALL_SERVICES=$(systemctl list-units --type=service --all --no-pager | wc -l)
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=running --no-pager | wc -l)
FAILED_SERVICES=$(systemctl list-units --type=service --state=failed --no-pager | wc -l)

SF_SERVICES=$(systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --all --no-pager | wc -l)
SF_ACTIVE=$(systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --state=active --no-pager | wc -l)
SF_FAILED=$(systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --state=failed --no-pager | wc -l)

FF_SERVICES=$(systemctl list-units "ff-*" "ffactory*" "factory-*" --all --no-pager | wc -l)
FF_ACTIVE=$(systemctl list-units "ff-*" "ffactory*" "factory-*" --state=active --no-pager | wc -l)

echo "📊 إحصائيات عامة:"
echo "   • إجمالي الخدمات: $ALL_SERVICES"
echo "   • الخدمات النشطة: $ACTIVE_SERVICES"
echo "   • الخدمات الفاشلة: $FAILED_SERVICES"
echo
echo "📊 إحصائيات SmartFriend Suite:"
echo "   • إجمالي الخدمات: $SF_SERVICES"
echo "   • الخدمات النشطة: $SF_ACTIVE"
echo "   • الخدمات الفاشلة: $SF_FAILED"
echo
echo "📊 إحصائيات ffactory:"
echo "   • إجمالي الخدمات: $FF_SERVICES"
echo "   • الخدمات النشطة: $FF_ACTIVE"

# 7) فحص الخدمات الأساسية المفصلة
log "7️⃣ فحص الخدمات الأساسية المفصلة:"

echo "🟢 الخدمات النشطة حالياً:"
systemctl list-units --state=running --no-pager | grep -E "(sf-|smartfrind|smartfriend|ff-|ffactory|factory)" | head -15

echo
echo "🔴 الخدمات الفاشلة:"
systemctl list-units --state=failed --no-pager | grep -E "(sf-|smartfrind|smartfriend|ff-|ffactory|factory)" || echo "   لا توجد خدمات فاشلة"

# 8) فحص البورتات
log "8️⃣ فحص البورتات النشطة:"
ss -tulpn | grep -E ':(8210|8211|8220|8383|8390|8000|8001|8170|5432|80|443)' | sort

# 9) فحص الموارد
log "9️⃣ فحص استخدام الموارد:"
echo "💻 استخدام CPU:"
top -bn1 | grep "Cpu(s)" | awk '{print "   الاستخدام: " $2 "%"}'

echo "🧠 استخدام الذاكرة:"
free -h | grep Mem | awk '{print "   الاستخدام: " $3 " من " $2 " (" $3/$2*100 "%)"}'

echo "💾 استخدام القرص:"
df -h / | awk 'NR==2 {print "   الاستخدام: " $5 " من " $2 " (" $3 " مستخدم)"}'

# 10) الخدمات التي تحتاج انتباه
log "🔟 الخدمات التي تحتاج انتباه:"

FAILED_LIST=$(systemctl list-units --state=failed --no-pager --plain | awk '{print $1}')
if [ -n "$FAILED_LIST" ]; then
    echo "🔍 تفاصيل الخدمات الفاشلة:"
    for service in $FAILED_LIST; do
        if [[ $service == *"sf-"* || $service == *"smartfrind"* || $service == *"smartfriend"* ]]; then
            echo "   ❌ $service"
            # عرض آخر خطأ من السجلات
            journalctl -u "$service" -n 1 --no-pager 2>/dev/null | grep -iE "(error|fail)" | head -1 | sed 's/^/      📝 /' || true
        fi
    done
else
    success "   ✅ لا توجد خدمات فاشلة تحتاج انتباه"
fi

echo
success "=== تم الانتهاء من الفحص الشامل للخدمات ==="
log "💡 للتشغيل الآمن استخدم: bash /root/sf_safe_startup.sh"
log "👀 للمراقبة المستمرة استخدم: bash /root/sf_final_monitor.sh"


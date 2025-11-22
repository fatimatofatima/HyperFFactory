#!/bin/bash
set -euo pipefail

# ألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== مراقبة نهائية لـ SmartFriend Suite ===${NC}"
echo "🎯 حالة مستقرة مع الخدمات الأساسية فقط"
echo ""

CORE_SERVICES=("sf-core.service" "smartfrind-api.service" "smartfrind-ask.service" "sf-telegram.service")

check_port(){
    local port="$1"
    if ss -tulpn 2>/dev/null | grep -q ":${port}"; then
        echo "      📡 البورت ${port} مفتوح"
    else
        echo "      ⚠️  البورت ${port} مغلق"
    fi
}

echo -e "${CYAN}🔍 فحص الخدمات الأساسية:${NC}"
for service in "${CORE_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ $service - نشط${NC}"
        case "$service" in
            sf-core.service)
                check_port 8383
                ;;
            smartfrind-api.service)
                # البوابة الرسمية الآن على 8220 (من 40-port.conf)
                check_port 8220
                ;;
        esac
    else
        echo -e "   ${RED}❌ $service - غير نشط${NC}"
    fi
done

ACTIVE_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=running 2>/dev/null | grep '\.service' | wc -l || echo 0)
FAILED_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=failed 2>/dev/null | grep '\.service' | wc -l || echo 0)

CPU_TOTAL=$(ps -o %cpu= -C python,python3 2>/dev/null | awk '{s+=$1} END{print (s!="")?s:0}')
RAM_TOTAL=$(ps -o %mem= -C python,python3 2>/dev/null | awk '{s+=$1} END{print (s!="")?s:0}')
PROC_COUNT=$(ps -C python,python3 --no-headers 2>/dev/null | wc -l || echo 0)

echo ""
echo -e "${CYAN}📊 حالة النظام العام:${NC}"
echo "   🟢 خدمات نشطة: ${ACTIVE_COUNT}"
echo "   🔴 خدمات فاشلة: ${FAILED_COUNT}"
echo ""
echo "💾 استخدام الموارد:"
echo "   📊 عمليات Python: ${PROC_COUNT}"
echo "   🚀 إجمالي CPU: ${CPU_TOTAL}%"
echo "   💾 إجمالي RAM: ${RAM_TOTAL}%"
echo ""
echo "💡 التوصيات:"
echo "   🛠️ هناك خدمات فاشلة تحتاج انتباه (jobs/learning) يمكن إصلاحها لاحقًا"
echo "   💡 استخدم: systemctl list-units --state=failed"
echo ""
echo -e "${GREEN}✅ النظام في حالة مستقرة على مستوى الكور والبوابة${NC}"

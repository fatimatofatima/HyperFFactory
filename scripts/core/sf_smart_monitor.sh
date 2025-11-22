#!/bin/bash

# ألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "============================================================"
echo "        SmartFriend Suite - المراقب الذكي"
echo "============================================================"
echo -e "${NC}"

# فحص سريع للخدمات الحرجة
declare -A services=(
    ["Gateway (8210)"]="ss -tulpn | grep ':8210'"
    ["Memory API (8214)"]="systemctl is-active sf-memory.service"
    ["Web UI (8390)"]="systemctl is-active sf-web.service" 
    ["Unified API (8220)"]="systemctl is-active sf-unified.service"
    ["Core API (8211)"]="systemctl is-active sf-core.service"
)

for service in "${!services[@]}"; do
    if eval "${services[$service]}" &>/dev/null; then
        echo -e "${GREEN}✅ $service${NC}"
    else
        echo -e "${RED}❌ $service${NC}"
    fi
done

# فحص المسارات
echo -e "\n${BLUE}🌐 مسارات Nginx:${NC}"
if curl -s http://localhost/dashboard/ &>/dev/null; then
    echo -e "${GREEN}✅ /dashboard/ - نشط${NC}"
else
    echo -e "${RED}❌ /dashboard/ - معطل${NC}"
fi

if curl -s http://localhost/memory/ &>/dev/null; then
    echo -e "${GREEN}✅ /memory/ - نشط${NC}"
else
    echo -e "${RED}❌ /memory/ - معطل${NC}"
fi

# نصيحة تلقائية
echo -e "\n${YELLOW}💡 التوصية الذكية:${NC}"
if ! systemctl is-active sf-memory.service &>/dev/null; then
    echo -e "🔧 تشغيل: sudo systemctl restart sf-memory.service"
elif ! systemctl is-active sf-web.service &>/dev/null; then
    echo -e "🔧 تشغيل: sudo systemctl restart sf-web.service"
else
    echo -e "✅ النظام يعمل بشكل جيد - التالي: bash /root/sf_finalize_bots.sh"
fi

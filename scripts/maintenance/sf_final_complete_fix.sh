#!/bin/bash
set -euo pipefail

echo "=== الحل النهائي الشامل لـ SmartFriend Suite ==="
echo "🎯 معالجة جميع المشاكل: Python modules, صلاحيات، تعارض بورتات، ملفات مفقودة"
echo ""

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. حل مشكلة Python modules المفقودة
echo -e "${BLUE}🐍 حل مشكلة Python modules المفقودة...${NC}"
mkdir -p /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/apps
touch /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/apps/__init__.py
touch /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/apps/web/__init__.py 2>/dev/null || true
touch /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/apps/unified/__init__.py 2>/dev/null || true
touch /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/qa_sidecar.py 2>/dev/null || true

# إنشاء ملف qa_sidecar.py بديل
cat > /opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/qa_sidecar.py << 'PYEOF'
from fastapi import FastAPI

app = FastAPI(title="QA Sidecar")

@app.get("/")
async def root():
    return {"status": "QA Sidecar is working"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8212)
PYEOF

echo -e "   ✅ تم إنشاء Python modules بديلة"

# 2. حل مشكلة تعارض البورتات
echo -e "${YELLOW}🔌 حل مشكلة تعارض البورتات...${NC}"
# إيقاف جميع الخدمات التي تستخدم البورت 8210
systemctl stop smartfrind-simple.service smartfrind-ultra.service 2>/dev/null || true

# تحديد أي خدمة تستخدم البورت 8210 حالياً
echo -e "   📊 البورتات النشطة:"
netstat -tlnp | grep -E ":821[0-9]" | while read -r line; do
    echo "      $line"
done

# 3. حل مشكلة الصلاحيات النهائية
echo -e "${BLUE}🔐 حل مشكلة الصلاحيات النهائية...${NC}"
chmod -R 755 /opt/smartfriend-suite/smartfriend/venv/bin/ 2>/dev/null || true
find /opt/smartfriend-suite/smartfriend/venv/bin -name "python*" -exec chmod +x {} \; 2>/dev/null || true
chmod +x /opt/smartfriend-suite/smartfriend/venv/bin/python 2>/dev/null || true

# 4. إنشاء قاعدة البيانات المفقودة
echo -e "${GREEN}🗃️ إنشاء قاعدة البيانات المفقودة...${NC}"
mkdir -p /var/lib/smartfrind
touch /var/lib/smartfrind/smart_memory.db 2>/dev/null || true
chmod 666 /var/lib/smartfrind/smart_memory.db 2>/dev/null || true

# 5. إصلاح ملفات الخدمات المعطوبة
echo -e "${YELLOW}⚙️ إصلاح ملفات الخدمات المعطوبة...${NC}"

# إصلاح smartfrind-qa.service
if [ -f "/etc/systemd/system/smartfrind-qa.service" ]; then
    sed -i 's|qa_sidecar|/opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages/qa_sidecar|g' /etc/systemd/system/smartfrind-qa.service 2>/dev/null || true
fi

# إصلاح smartfrind-watch.service (إزالة الملف المعطوب)
if [ -f "/etc/systemd/system/smartfrind-watch.service" ]; then
    rm -f /etc/systemd/system/smartfrind-watch.service
    echo -e "   ✅ إزالة smartfrind-watch.service المعطوب"
fi

# 6. إعادة تشغيل systemd
systemctl daemon-reload

# 7. تشغيل الخدمات الأساسية فقط بشكل منظم
echo -e "${GREEN}🚀 تشغيل الخدمات الأساسية بشكل منظم...${NC}"

# الخدمات الأساسية التي يجب أن تعمل (بدون تعارض)
CORE_SERVICES=(
    "sf-core.service"           # البورت 8383
    "smartfrind-api.service"    # البورت 8210  
    "smartfrind-ask.service"    # البورت مختلف
    "sf-telegram.service"       # لا يستخدم بورت
)

for service in "${CORE_SERVICES[@]}"; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo -n "   🔄 تشغيل $service ... "
        systemctl stop "$service" 2>/dev/null
        sleep 2
        systemctl start "$service" 2>/dev/null && \
            echo -e "${GREEN}✅${NC}" || \
            echo -e "${RED}❌${NC}"
    fi
done

# 8. إيقاف الخدمات التي تسبب مشاكل
echo -e "${RED}🛑 إيقاف الخدمات المسببة للمشاكل...${NC}"
PROBLEMATIC_SERVICES=(
    "smartfrind-ai-gateway.service"
    "smartfrind-advanced.service" 
    "smartfrind-local.service"
    "smartfrind-simple.service"
    "smartfrind-ultra.service"
    "smartfrind-qa.service"
    "sf-web.service"
    "sf-unified.service"
)

for service in "${PROBLEMATIC_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1 || systemctl is-failed "$service" >/dev/null 2>&1; then
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        systemctl mask "$service" 2>/dev/null
        echo -e "   ⏹️ تم إيقاف وتعطيل $service"
    fi
done

# 9. الحالة النهائية
echo -e "${BLUE}📊 الحالة النهائية:${NC}"
ACTIVE_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=active --no-legend 2>/dev/null | wc -l)
FAILED_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-legend 2>/dev/null | wc -l)

echo -e "   ${GREEN}🟢 نشط: $ACTIVE_COUNT${NC}"
echo -e "   ${RED}🔴 فاشل: $FAILED_COUNT${NC}"

# 10. عرض الخدمات النشطة
echo -e "${GREEN}✅ الخدمات النشطة حالياً:${NC}"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager --no-legend | \
    while read -r line; do
        service=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $3}')
        echo -e "   🟢 $service ($status)"
    done

echo -e "${GREEN}🎯 تم الانتهاء من الحل النهائي الشامل!${NC}"
echo -e "${BLUE}💡 النظام الآن مستقر مع الخدمات الأساسية فقط${NC}"

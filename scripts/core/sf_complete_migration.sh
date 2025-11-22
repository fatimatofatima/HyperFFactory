#!/bin/bash
set -euo pipefail

echo "=== النقل والإصلاح الشامل لـ SmartFriend Suite ==="
echo "🎯 الهدف: نقل كامل الخدمات بدون symbolic links وعزل تام عن ffactory"
echo ""

# تعريف المسارات
SUITE_ROOT="/opt/smartfriend-suite"
BACKUP_DIR="/root/sf_backup_$(date +%Y%m%d_%H%M%S)"
SERVICES_DIR="/etc/systemd/system"

# ألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}📁 إنشاء نسخة احتياطية...${NC}"
cp -r $SERVICES_DIR/sf-* $BACKUP_DIR/ 2>/dev/null || true
cp -r $SERVICES_DIR/smartfriend* $BACKUP_DIR/ 2>/dev/null || true

echo -e "${BLUE}🔍 جمع جميع خدمات السويت...${NC}"
ALL_SF_SERVICES=$(systemctl list-unit-files --type=service | \
    grep -E '^(sf-|smartfriend|smartfrind)' | \
    grep -v ffactory | \
    awk '{print $1}')

echo "📋 عدد الخدمات المكتشفة: $(echo "$ALL_SF_SERVICES" | wc -l)"

# الخطوة 1: إيقاف جميع الخدمات أولاً
echo -e "${YELLOW}🛑 إيقاف جميع الخدمات...${NC}"
for service in $ALL_SF_SERVICES; do
    systemctl stop "$service" 2>/dev/null || true
    systemctl disable "$service" 2>/dev/null || true
done

# الخطوة 2: تنظيف وإعادة إنشاء ملفات الخدمات
echo -e "${BLUE}🧹 تنظيف وإعادة إنشاء ملفات الخدمات...${NC}"
for service in $ALL_SF_SERVICES; do
    UNIT_FILE="$SERVICES_DIR/$service"
    
    if [ -f "$UNIT_FILE" ]; then
        echo "   🔧 معالجة: $service"
        
        # إزالة أي symbolic links
        if [ -L "$UNIT_FILE" ]; then
            rm -f "$UNIT_FILE"
            echo "     ❌ حذف symbolic link: $service"
        fi
        
        # إذا كان ملف حقيقي، نقوم بإصلاحه
        if [ -f "$UNIT_FILE" ]; then
            # إصلاح WorkingDirectory إذا كان فارغاً
            if ! grep -q "WorkingDirectory=" "$UNIT_FILE"; then
                echo "WorkingDirectory=/opt/smartfriend-suite" >> "$UNIT_FILE"
                echo "     ✅ إضافة WorkingDirectory"
            fi
            
            # إصلاح المسارات المطلوبة
            sed -i 's|/opt/ffactory|/opt/smartfriend-suite|g' "$UNIT_FILE" 2>/dev/null || true
        fi
    fi
done

# الخطوة 3: إعادة تحميل systemd
systemctl daemon-reload

# الخطوة 4: تشغيل الخدمات الأساسية أولاً
echo -e "${GREEN}🚀 تشغيل الخدمات الأساسية...${NC}"
CORE_SERVICES="sf-core.service smartfrind-api.service smartfrind-ask.service smartfrind-simple.service smartfrind-ultra.service"

for service in $CORE_SERVICES; do
    if echo "$ALL_SF_SERVICES" | grep -q "$service"; then
        systemctl enable "$service" 2>/dev/null && \
        systemctl start "$service" 2>/dev/null && \
        echo -e "     ✅ $service - تم التشغيل" || \
        echo -e "     ❌ $service - فشل التشغيل"
    fi
done

# الخطوة 5: تشغيل باقي الخدمات
echo -e "${BLUE}🔧 تشغيل باقي الخدمات...${NC}"
for service in $ALL_SF_SERVICES; do
    # تخطي الخدمات الأساسية التي تم تشغيلها بالفعل
    if echo "$CORE_SERVICES" | grep -q "$service"; then
        continue
    fi
    
    # تخطي الخدمات المعطوبة
    if [[ "$service" =~ (ai-gateway|advanced|local) ]]; then
        echo "     ⏭️ تخطي $service (مشاكل معروفة)"
        continue
    fi
    
    systemctl enable "$service" 2>/dev/null && \
    systemctl start "$service" 2>/dev/null && \
    echo -e "     ✅ $service - تم التشغيل" || \
    echo -e "     ❌ $service - فشل التشغيل"
done

# الخطوة 6: الحالة النهائية
echo -e "${GREEN}📊 الحالة النهائية:${NC}"
ACTIVE_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=active --no-legend 2>/dev/null | wc -l)
FAILED_COUNT=$(systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-legend 2>/dev/null | wc -l)

echo -e "   🟢 نشط: $ACTIVE_COUNT"
echo -e "   🔴 فاشل: $FAILED_COUNT"
echo -e "   📁 نسخة احتياطية: $BACKUP_DIR"

echo -e "${GREEN}🎯 تم الانتهاء من النقل والإصلاح الشامل!${NC}"

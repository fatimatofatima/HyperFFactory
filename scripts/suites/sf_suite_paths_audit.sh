#!/usr/bin/env bash
set -Eeuo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== SmartFriend Suite Paths Audit - تقرير المسارات ===${NC}"
echo -e "${BLUE}الهدف: فحص جميع مسارات SmartFriend بدون تعديل${NC}\n"

# 1. فحص خدمات systemd
echo -e "${BLUE}1️⃣ خدمات SmartFriend Systemd:${NC}"

SERVICES=$(systemctl list-unit-files --type=service --no-legend | grep -E '(sf-|smartfriend|smartfrind)' | awk '{print $1}')

declare -A STATUS_CATEGORIES=(
    ["نظيفة"]=0
    ["مختلطة"]=0 
    ["فاشلة"]=0
)

for service in $SERVICES; do
    echo -e "\n${YELLOW}--- $service ---${NC}"
    
    # حالة الخدمة
    STATUS=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
    if [[ "$STATUS" == "failed" ]]; then
        COLOR=$RED
        ((STATUS_CATEGORIES["فاشلة"]++))
    elif [[ "$STATUS" == "active" ]]; then
        COLOR=$GREEN
    else
        COLOR=$YELLOW
    fi
    echo -e "${COLOR}الحالة: $STATUS${NC}"
    
    # مسار التنفيذ
    EXEC_START=$(systemctl show "$service" --property=ExecStart --no-pager | cut -d= -f2-)
    echo "ExecStart: $EXEC_START"
    
    # مجلد العمل
    WORK_DIR=$(systemctl show "$service" --property=WorkingDirectory --no-pager | cut -d= -f2-)
    echo "WorkingDirectory: $WORK_DIR"
    
    # تحليل المسارات
    if [[ "$EXEC_START" == *"/opt/smartfriend-suite"* ]] && 
       [[ "$EXEC_START" != *"/root/"* ]] && 
       [[ "$WORK_DIR" == *"/opt/smartfriend-suite"* || -z "$WORK_DIR" ]]; then
        echo -e "${GREEN}✅ تصنيف: نظيفة${NC}"
        ((STATUS_CATEGORIES["نظيفة"]++))
    elif [[ "$EXEC_START" == *"/root/"* ]] || [[ "$EXEC_START" == *"/opt/smartfrind"* ]]; then
        echo -e "${YELLOW}⚠️ تصنيف: مختلطة${NC}"
        ((STATUS_CATEGORIES["مختلطة"]++))
    else
        echo -e "${RED}❓ تصنيف: غير معروف${NC}"
    fi
done

# 2. فحص Symlinks
echo -e "\n${BLUE}2️⃣ فحص الـ Symlinks في /opt:${NC}"
find /opt -maxdepth 2 -type l -name "*smart*" -exec ls -la {} \; 2>/dev/null | while read -r line; do
    echo "$line"
done

# 3. فحص الملفات في /root المرتبطة بالخدمات
echo -e "\n${BLUE}3️⃣ سكربتات الـ Auto-Learning في /root:${NC}"
for script in /root/smartfrind_auto_learning.sh /root/auto_learning_agent.sh; do
    if [[ -f "$script" ]]; then
        echo -e "${YELLOW}📄 $script${NC}"
        echo "   الحجم: $(ls -lh "$script" | awk '{print $5}')"
        echo "   السطور: $(wc -l < "$script")"
        echo "   أول سطر: $(head -1 "$script")"
    else
        echo -e "${RED}❌ $script - غير موجود${NC}"
    fi
done

# 4. فحص هيكل مجلدات suite
echo -e "\n${BLUE}4️⃣ هيكل /opt/smartfriend-suite:${NC}"
find /opt/smartfriend-suite -maxdepth 3 -type d -name "*" | sort | while read -r dir; do
    if [[ "$dir" == *"backup"* || "$dir" == *"data"* || "$dir" == *"script"* ]]; then
        echo "📁 $dir"
    fi
done

# 5. إحصائيات نهائية
echo -e "\n${BLUE}📊 الإحصائيات النهائية:${NC}"
for category in "${!STATUS_CATEGORIES[@]}"; do
    count=${STATUS_CATEGORIES[$category]}
    case $category in
        "نظيفة") COLOR=$GREEN ;;
        "مختلطة") COLOR=$YELLOW ;;
        "فاشلة") COLOR=$RED ;;
        *) COLOR=$NC ;;
    esac
    echo -e "${COLOR}  $category: $count خدمات${NC}"
done

echo -e "\n${BLUE}🎯 التوصيات بناءً على التقرير:${NC}"
echo "1. الخدمات 'النظيفة' - لا تحتاج تعديل"
echo "2. الخدمات 'المختلطة' - تحتاج توحيد مسارات"
echo "3. الخدمات 'الفاشلة' - تحتاج إصلاح عاجل"
echo "4. السكربتات في /root - تحتاج نقل لـ /opt/smartfriend-suite/scripts"


#!/bin/bash
echo "📊 عرض المجلدات الكبيرة بالتفصيل"
echo "================================"

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔍 فحص جميع مجلدات hyper-factory...${NC}"
echo ""

# 1. أكبر 20 مجلد في /root
echo -e "${YELLOW}🏆 أكبر 20 مجلد في /root:${NC}"
du -h /root/* 2>/dev/null | sort -rh | head -20 | while read size name; do
    echo -e "  ${GREEN}📁 $size${NC} - ${BLUE}$name${NC}"
done

echo ""

# 2. تحليل مفصل لمجلدات hyper-factory
echo -e "${YELLOW}🏭 تحليل مفصل لمجلدات hyper-factory:${NC}"
for dir in /root/hyper-factory*; do
    if [ -d "$dir" ]; then
        total_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}📦 $total_size${NC} - ${BLUE}$(basename $dir)${NC} - ${PURPLE}$file_count ملف${NC}"
    fi
done

echo ""

# 3. أكبر المجلدات داخل hyper-factory الرئيسي
echo -e "${YELLOW}📂 أكبر المجلدات داخل hyper-factory الرئيسي:${NC}"
if [ -d "/root/hyper-factory" ]; then
    du -h /root/hyper-factory/* 2>/dev/null | sort -rh | head -15 | while read size name; do
        folder_name=$(basename "$name")
        echo -e "  ${GREEN}📁 $size${NC} - ${BLUE}$folder_name${NC}"
    done
fi

echo ""

# 4. أكبر المجلدات داخل hyper-factory-merged
echo -e "${YELLOW}🔄 أكبر المجلدات داخل hyper-factory-merged:${NC}"
if [ -d "/root/hyper-factory-merged" ]; then
    du -h /root/hyper-factory-merged/* 2>/dev/null | sort -rh | head -15 | while read size name; do
        folder_name=$(basename "$name")
        echo -e "  ${GREEN}📁 $size${NC} - ${BLUE}$folder_name${NC}"
    done
fi

echo ""

# 5. الملفات الكبيرة جدا (أكثر من 100MB)
echo -e "${RED}🚨 الملفات الكبيرة جدا (أكثر من 100MB):${NC}"
find /root -type f -size +100M -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -10 | while read line; do
    size=$(echo "$line" | awk '{print $5}')
    file=$(echo "$line" | awk '{print $9}')
    echo -e "  ${RED}⚠️  $size${NC} - ${PURPLE}$file${NC}"
done

echo ""

# 6. إحصائيات المساحة
echo -e "${CYAN}💾 إحصائيات المساحة الحالية:${NC}"
df -h /root | while read line; do
    echo -e "  ${GREEN}$line${NC}"
done

echo ""

# 7. اقتراحات التنظيف
echo -e "${YELLOW}💡 اقتراحات للتنظيف:${NC}"
echo -e "  ${GREEN}1.${NC} مجلدات hyper-factory المكررة (merged, unified, unique)"
echo -e "  ${GREEN}2.${NC} ملفات السجلات الكبيرة (.log)"
echo -e "  ${GREEN}3.${NC} قواعد البيانات المكررة (.db)"
echo -e "  ${GREEN}4.${NC} مجلدات النسخ الاحتياطي القديمة"

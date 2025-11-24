#!/bin/bash
echo "📊 فحص نتائج حذف التكرار"
echo "========================"

# الألوان
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}🔍 فحص المجلدات النهائية:${NC}"

# فحص hyper-factory-optimized (النتيجة السابقة)
if [ -d "/root/hyper-factory-optimized" ]; then
    count_opt=$(find "/root/hyper-factory-optimized" -type f \( -name "*.py" -o -name "*.sh" \) 2>/dev/null | wc -l)
    size_opt=$(du -sh "/root/hyper-factory-optimized" 2>/dev/null | cut -f1)
    echo -e "  ${GREEN}✓ hyper-factory-optimized:${NC} $count_opt ملف - $size_opt"
fi

# فحص hyper-factory-unique-ultimate (النتيجة الجديدة)
if [ -d "/root/hyper-factory-unique-ultimate" ]; then
    count_ult=$(find "/root/hyper-factory-unique-ultimate" -type f \( -name "*.py" -o -name "*.sh" \) 2>/dev/null | wc -l)
    size_ult=$(du -sh "/root/hyper-factory-unique-ultimate" 2>/dev/null | cut -f1)
    echo -e "  ${BLUE}✓ hyper-factory-unique-ultimate:${NC} $count_ult ملف - $size_ult"
fi

# مقارنة مع الأصل
if [ -d "/root/hyper-factory" ]; then
    count_orig=$(find "/root/hyper-factory" -type f \( -name "*.py" -o -name "*.sh" \) 2>/dev/null | wc -l)
    size_orig=$(du -sh "/root/hyper-factory" 2>/dev/null | cut -f1)
    echo -e "  ${YELLOW}📁 الأصل (hyper-factory):${NC} $count_orig ملف - $size_orig"
fi

echo -e ""
echo -e "${GREEN}📈 ملخص التوفير:${NC}"

if [ -d "/root/hyper-factory-optimized" ] && [ -d "/root/hyper-factory" ]; then
    saved=$((count_orig - count_opt))
    saved_percent=$((saved * 100 / count_orig))
    echo -e "  ${GREEN}• hyper-factory-optimized وفر:${NC} $saved ملف ($saved_percent%)"
fi

echo -e ""
echo -e "${BLUE}💡 التوصيات:${NC}"
echo -e "  1. استخدام hyper-factory-optimized للإنتاج"
echo -e "  2. حذف المجلدات المكررة لتوفير المساحة"
echo -e "  3. تشغيل hf_hash_dedupe_ultimate.sh لمزيد من التحسين"

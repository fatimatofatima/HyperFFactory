#!/bin/bash
echo "🚀 تحسين شامل للنظام - 6 أنوية"
echo "================================"

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. تنظيف الملفات المؤقتة
echo -e "${YELLOW}1. تنظيف الملفات المؤقتة...${NC}"
find /tmp -name "*.tmp" -type f -delete 2>/dev/null
find /root -name "*.log" -size +5M -exec truncate -s 1M {} \; 2>/dev/null
echo -e "${GREEN}✅ تم تنظيف الملفات المؤقتة${NC}"

# 2. تقليص ملفات السجلات الكبيرة
echo -e "${YELLOW}2. تقليص ملفات السجلات...${NC}"
find /root -name "*.log" -size +10M -exec ls -lh {} \; 2>/dev/null | head -10
find /root -name "*.log" -size +10M -exec truncate -s 5M {} \; 2>/dev/null
echo -e "${GREEN}✅ تم تقليص السجلات${NC}"

# 3. حذف المجلدات المكررة
echo -e "${YELLOW}3. تنظيف المجلدات المكررة...${NC}"
rm -rf /root/hyper-factory_broken_* 2>/dev/null
rm -rf /root/hyper-factory-clean-fast 2>/dev/null
rm -rf /root/hyper-factory-unique 2>/dev/null
echo -e "${GREEN}✅ تم حذف المجلدات المكررة${NC}"

# 4. دمج الملفات الفريدة
echo -e "${YELLOW}4. دمج الملفات الفريدة...${NC}"
DEST="/root/hyper-factory-optimized"
rm -rf "$DEST"
mkdir -p "$DEST"

# جمع الملفات من المصادر المختلفة
find /root/hyper-factory-merged -type f \( -name "*.py" -o -name "*.sh" \) > /tmp/all_files.txt
find /root/hyper-factory-unique-final -type f \( -name "*.py" -o -name "*.sh" \) >> /tmp/all_files.txt

# استخدام parallel لحساب الهاش وتصفية التكرار
echo -e "${BLUE}🔍 معالجة $(cat /tmp/all_files.txt | wc -l) ملف...${NC}"
cat /tmp/all_files.txt | head -15000 | parallel -j6 --bar md5sum | \
sort -u -k1,1 | awk '{print $2}' | \
parallel -j6 "cp --parents {} $DEST/ 2>/dev/null"

# 5. تنظيف ذاكرة التخزين المؤقت
echo -e "${YELLOW}5. تحسين الذاكرة...${NC}"
sync
echo 3 > /proc/sys/vm/drop_caches

# 6. الإحصائيات النهائية
echo -e "${YELLOW}6. الإحصائيات النهائية...${NC}"
TOTAL_FILES=$(cat /tmp/all_files.txt | wc -l)
UNIQUE_FILES=$(find "$DEST" -type f | wc -l)
FREED_SPACE=$(du -sh /root/hyper-factory-* | sort -h | tail -1 | cut -f1)

echo -e "${GREEN}📊 النتائج:${NC}"
echo -e "• ${BLUE}إجمالي الملفات:${NC} $TOTAL_FILES"
echo -e "• ${BLUE}الملفات الفريدة:${NC} $UNIQUE_FILES"
echo -e "• ${BLUE}نسبة التكرار:${NC} $(( (TOTAL_FILES - UNIQUE_FILES) * 100 / TOTAL_FILES ))%"
echo -e "• ${BLUE}المسار المحسن:${NC} $DEST"
echo -e "• ${GREEN}✅ تم تحرير مساحة كبيرة${NC}"

# 7. فحص المساحة النهائي
echo -e "${YELLOW}7. فحص المساحة النهائي...${NC}"
df -h /root

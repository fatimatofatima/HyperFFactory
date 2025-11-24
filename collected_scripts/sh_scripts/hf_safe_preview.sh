#!/bin/bash
echo "🔍 معاينة آمنة قبل الحذف"
echo "========================"

echo -e "📊 سأقوم بحذف هذه الملفات/المجلدات:"
echo ""

# 1. النسخ الاحتياطية الكبيرة
echo "🗂️ النسخ الاحتياطية الكبيرة:"
du -sh /root/backup_sfs_old_2025-11-12.tar.gz 2>/dev/null
du -sh /root/important_backups/backup_20251111_044632.tar.gz 2>/dev/null
du -sh /root/magic_all_20251112_182509 2>/dev/null | head -5
echo ""

# 2. صور Android
echo "📱 صور Android الكبيرة:"
find /root -name "system.img" -size +1G -exec ls -lh {} \; 2>/dev/null | head -10
echo ""

# 3. مجلدات hyper-factory المكررة
echo "🏭 مجلدات hyper-factory المكررة:"
du -sh /root/hyper-factory-merged 2>/dev/null
du -sh /root/hyper-factory-unified 2>/dev/null
du -sh /root/hyper-factory_broken_* 2>/dev/null | head -5
echo ""

# 4. قواعد البيانات المكررة
echo "🗃️ قواعد البيانات المكررة:"
find /root -name "smartfriend_unified.db" -size +100M -exec ls -lh {} \; 2>/dev/null | head -10
echo ""

# الإجمالي المتوقع
echo "💡 المساحة المتوقع تحريرها:"
TOTAL_ESTIMATED=0
for item in \
    /root/backup_sfs_old_2025-11-12.tar.gz \
    /root/important_backups/backup_20251111_044632.tar.gz \
    /root/magic_all_20251112_182509 \
    /root/hyper-factory-merged \
    /root/hyper-factory-unified; do
    if [ -e "$item" ]; then
        size_mb=$(du -sm "$item" 2>/dev/null | cut -f1)
        TOTAL_ESTIMATED=$((TOTAL_ESTIMATED + size_mb))
    fi
done

echo -e "📈 إجمالي المساحة المتوقع تحريرها: ${GREEN}$(echo "scale=2; $TOTAL_ESTIMATED / 1024" | bc) GB${NC}"
echo ""
echo "⚠️  هل تريد المتابعة؟ (y/n)"
read -r response
if [ "$response" = "y" ]; then
    echo "🚀 تشغيل التنظيف المتقدم..."
    /root/hf_advanced_cleanup.sh
else
    echo "❌ تم إلغاء العملية"
fi

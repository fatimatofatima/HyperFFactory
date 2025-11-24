#!/bin/bash
echo "🧹 تنظيف متقدم - تحرير مساحة ضخمة"
echo "================================"

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

TOTAL_FREED=0

# دالة لحساب المساحة المحررة
add_freed_space() {
    local size=$1
    TOTAL_FREED=$((TOTAL_FREED + size))
    echo -e "${GREEN}✅ تم تحرير: $size MB${NC}"
}

# 1. حذف النسخ الاحتياطية القديمة الضخمة
echo -e "${YELLOW}1. حذف النسخ الاحتياطية القديمة...${NC}"
large_backups=(
    "/root/backup_sfs_old_2025-11-12.tar.gz"                      # 13GB
    "/root/important_backups/backup_20251111_044632.tar.gz"       # 5.3GB
    "/root/magic_all_20251112_182509"                             # مجلد كبير
    "/root/db_cleanup_backup_20251115_060119"                     # مجلد كبير
)

for backup in "${large_backups[@]}"; do
    if [ -e "$backup" ]; then
        size_mb=$(du -sm "$backup" 2>/dev/null | cut -f1)
        echo -e "${RED}🗑️ حذف: $backup (${size_mb}MB)${NC}"
        rm -rf "$backup"
        add_freed_space "$size_mb"
    fi
done

# 2. تنظيف مجلدات Android الكبيرة
echo -e "${YELLOW}2. تنظيف صور Android الكبيرة...${NC}"
android_images=(
    "/root/hyper-factory/backups/pre_real_merge_20251121_110456/hyper-factory/integration/backups/pre_merge/smartfriend-suite_backup_20251121_104510/imported/toolchains/android-sdk/system-images"
    "/root/hyper-factory/integration/backups/pre_merge/hyper-factory_backup_20251121_104510/integration/backups/pre_merge/smartfriend-suite_backup_20251121_104510/imported/toolchains/android-sdk/system-images"
    "/root/hyper-factory/integration/backups/pre_merge/smartfriend-suite_backup_20251121_104510/imported/toolchains/android-sdk/system-images"
    "/root/.android/avd/*/snapshots/default_boot/ram.img"
)

for android_path in "${android_images[@]}"; do
    if [ -e "$android_path" ]; then
        size_mb=$(du -sm "$android_path" 2>/dev/null | cut -f1)
        echo -e "${RED}🗑️ حذف: $android_path (${size_mb}MB)${NC}"
        rm -rf "$android_path"
        add_freed_space "$size_mb"
    fi
done

# 3. حذف النسخ المكررة من hyper-factory
echo -e "${YELLOW}3. حذف النسخ المكررة من hyper-factory...${NC}"
duplicate_dirs=(
    "/root/hyper-factory-merged"
    "/root/hyper-factory-unified" 
    "/root/hyper-factory-unique-final"
    "/root/hyper-factory-clean-fast"
    "/root/hyper-factory-final"
    "/root/hyper-factory_broken_*"
    "/root/hyper-factory-backup-direct-20251121_111236"
    "/root/hyper-factory-backup-20251121_092733"
)

for dir in "${duplicate_dirs[@]}"; do
    if [ -e "$dir" ]; then
        size_mb=$(du -sm "$dir" 2>/dev/null | cut -f1)
        echo -e "${RED}🗑️ حذف: $dir (${size_mb}MB)${NC}"
        rm -rf "$dir"
        add_freed_space "$size_mb"
    fi
done

# 4. تنظيف قواعد البيانات المكررة
echo -e "${YELLOW}4. تنظيف قواعد البيانات المكررة...${NC}"
db_patterns=(
    "/root/opt-projects/smartfriend-suite*"
    "/root/magic_all_20251112_182509/opt/smartfriend-suite*"
    "/root/hyper-factory/backups/pre_real_merge_20251121_110456/hyper-factory/integration/backups/pre_merge/smartfriend-suite_backup_20251121_104510"
    "/root/hyper-factory/integration/backups/pre_merge/hyper-factory_backup_20251121_104510"
    "/root/hyper-factory/integration/backups/pre_merge/smartfriend-suite_backup_20251121_104510"
)

for pattern in "${db_patterns[@]}"; do
    for db_path in $pattern; do
        if [ -e "$db_path" ]; then
            size_mb=$(du -sm "$db_path" 2>/dev/null | cut -f1)
            echo -e "${RED}🗑️ حذف: $db_path (${size_mb}MB)${NC}"
            rm -rf "$db_path"
            add_freed_space "$size_mb"
        fi
    done
done

# 5. تنظيف مجلدات ffactory القديمة
echo -e "${YELLOW}5. تنظيف مجلدات ffactory القديمة...${NC}"
ffactory_dirs=(
    "/root/opt-projects/ffactory/backup/upgrade_20251030_030127"
    "/root/opt-projects/ffactory/backup/upgrade_20251030_025926"
)

for ffactory in "${ffactory_dirs[@]}"; do
    if [ -e "$ffactory" ]; then
        size_mb=$(du -sm "$ffactory" 2>/dev/null | cut -f1)
        echo -e "${RED}🗑️ حذف: $ffactory (${size_mb}MB)${NC}"
        rm -rf "$ffactory"
        add_freed_space "$size_mb"
    fi
done

# 6. تنظيف الذاكرة المؤقتة
echo -e "${YELLOW}6. تنظيف الذاكرة المؤقتة...${NC}"
sync
echo 3 > /proc/sys/vm/drop_caches

# النتائج النهائية
echo -e "${PURPLE}================================${NC}"
echo -e "${GREEN}🎉 النتائج النهائية:${NC}"
echo -e "${BLUE}• إجمالي المساحة المحررة: $TOTAL_FREED MB${NC}"
echo -e "${BLUE}• إجمالي المساحة المحررة: $(echo "scale=2; $TOTAL_FREED / 1024" | bc) GB${NC}"

# فحص المساحة النهائي
echo -e "${YELLOW}💾 المساحة الحالية:${NC}"
df -h /root

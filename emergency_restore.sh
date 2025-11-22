#!/bin/bash
echo "🚨 استعادة طارئة للقواعد المحذوفة"

# المصادر المحتملة للاستعادة
SOURCE_DIRS=(
    "/root/HyperFFactory/all_archives_unpacked_20251122_075957"
    "/root/HyperFFactory/backups_legacy" 
    "/root/HyperFFactory/final_legacy_backup_20251122_074926"
)

RESTORE_DIR="/root/HyperFFactory/emergency_restore_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESTORE_DIR"

for source_dir in "${SOURCE_DIRS[@]}"; do
    if [ -d "$source_dir" ]; then
        echo "🔍 البحث في: $source_dir"
        find "$source_dir" -name "*.db" -exec cp {} "$RESTORE_DIR/" \; 2>/dev/null
    fi
done

echo "✅ تم الاستعادة إلى: $RESTORE_DIR"
echo "📊 عدد القواعد المستعادة: $(ls -1 "$RESTORE_DIR"/*.db 2>/dev/null | wc -l)"

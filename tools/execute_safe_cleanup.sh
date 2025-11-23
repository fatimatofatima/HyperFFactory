#!/bin/bash

echo "🧹 بدء عملية تنظيف قواعد البيانات القديمة"
echo "========================================"

# التحقق النهائي من النظام الجديد
echo "🔍 التحقق النهائي من النظام الجديد..."
./tools/final_verification.sh

echo ""
echo "📊 الإحصائيات النهائية:"
echo "   - المعرفة الجديدة: 804M (152,053 مستند)"
echo "   - الذاكرة الجديدة: 360K (619 حدث)" 
echo "   - القواعد القديمة: $(find /root/HyperFFactory/backups_legacy -name "*.db" | wc -l) قاعدة"

# طلب التأكيد النهائي
echo ""
read -p "⚠️  هل تريد متابعة حذف جميع قواعد البيانات القديمة؟ (اكتب 'نعم' للمتابعة): " CONFIRM

if [ "$CONFIRM" != "نعم" ]; then
    echo "❌ تم إلغاء العملية"
    exit 0
fi

# بدء الحذف
echo "🗑️  بدء عملية الحذف..."
TOTAL_DELETED=0
TOTAL_SIZE=0

# حذف قواعد البيانات القديمة فقط (احتفظ بالملفات الأخرى)
while IFS= read -r db_file; do
    if [ -f "$db_file" ]; then
        SIZE=$(du -k "$db_file" | cut -f1)
        TOTAL_SIZE=$((TOTAL_SIZE + SIZE))
        rm "$db_file"
        TOTAL_DELETED=$((TOTAL_DELETED + 1))
        echo "✅ محذوف: $(basename "$db_file") (${SIZE}KB)"
    fi
done < <(find /root/HyperFFactory/backups_legacy -name "*.db")

echo ""
echo "🎉 عملية التنظيف اكتملت!"
echo "📊 الإحصائيات النهائية:"
echo "   - عدد القواعد المحذوفة: $TOTAL_DELETED"
echo "   - المساحة المُحررة: $((TOTAL_SIZE / 1024)) MB"
echo "   - النسخة الاحتياطية محفوظة في: /root/HyperFFactory/final_legacy_backup_*"

# التحقق من النظام بعد الحذف
echo ""
echo "🔍 التحقق من النظام بعد الحذف:"
echo "المساحة الحالية:"
du -sh /root/HyperFFactory/
echo ""
echo "البيانات الجديدة (يجب أن تكون سليمة):"
./tools/final_verification.sh

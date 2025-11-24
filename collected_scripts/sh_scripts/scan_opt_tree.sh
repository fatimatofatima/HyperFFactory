#!/bin/bash

echo "================================================"
echo "   📁 مسح كامل لمجلد /opt بنظام الشجرة"
echo "================================================"
echo "الوقت: $(date)"
echo "================================================"

# دالة لعرض حجم الملف بشكل مقروء
human_size() {
    local size=$1
    if [ $size -ge 1073741824 ]; then
        echo "$(echo "scale=2; $size/1073741824" | bc) GB"
    elif [ $size -ge 1048576 ]; then
        echo "$(echo "scale=2; $size/1048576" | bc) MB"
    elif [ $size -ge 1024 ]; then
        echo "$(echo "scale=2; $size/1024" | bc) KB"
    else
        echo "${size} B"
    fi
}

# دالة للمسح العادي
scan_normal() {
    echo "📊 المسح العادي:"
    echo "----------------"
    find /opt -type f -exec ls -la {} \; 2>/dev/null | head -50
    echo "... (يتم عرض أول 50 ملف فقط)"
}

# دالة للمسح كشجرة مع التفاصيل
scan_tree_detailed() {
    echo ""
    echo "🌳 المسح كشجرة مفصلة:"
    echo "---------------------"
    
    # استخدام tree إذا موجود
    if command -v tree &> /dev/null; then
        tree /opt -a -L 3 -s -h 2>/dev/null | head -100
    else
        # بديل إذا tree غير موجود
        echo "⚠️  الأمر 'tree' غير مثبت، استخدام find بدلاً منه:"
        find /opt -type d 2>/dev/null | head -30 | while read dir; do
            echo "📁 $dir"
            find "$dir" -maxdepth 1 -type f -exec ls -lh {} \; 2>/dev/null | head -5
        done
    fi
}

# دالة لعرض الإحصائيات
show_stats() {
    echo ""
    echo "📈 إحصائيات /opt:"
    echo "-----------------"
    
    total_files=$(find /opt -type f 2>/dev/null | wc -l)
    total_dirs=$(find /opt -type d 2>/dev/null | wc -l)
    total_size=$(du -sb /opt 2>/dev/null | cut -f1)
    
    echo "📂 المجلدات: $total_dirs"
    echo "📄 الملفات: $total_files"
    echo "💾 الحجم الإجمالي: $(human_size $total_size)"
    
    # أكبر 10 ملفات
    echo ""
    echo "🔝 أكبر 10 ملفات في /opt:"
    find /opt -type f -exec ls -la {} \; 2>/dev/null | sort -k5 -nr | head -10 | while read line; do
        size=$(echo $line | awk '{print $5}')
        file=$(echo $line | awk '{print $9}')
        echo "  $(human_size $size) - $file"
    done
}

# دالة للملفات المهمة في smartfriend-suite
show_smartfriend_files() {
    if [ -d "/opt/smartfriend-suite" ]; then
        echo ""
        echo "🤖 ملفات SmartFriend المهمة:"
        echo "---------------------------"
        find /opt/smartfriend-suite -type f -name "*.db" -o -name "*.sh" -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read file; do
            if [ -f "$file" ]; then
                size=$(stat -c%s "$file" 2>/dev/null || echo "0")
                echo "  📄 $(human_size $size) - $file"
            fi
        done | head -20
    fi
}

# التنفيذ الرئيسي
main() {
    scan_normal
    scan_tree_detailed
    show_stats
    show_smartfriend_files
    
    echo ""
    echo "================================================"
    echo "تم المسح بنجاح! 🎯"
    echo "================================================"
}

# تشغيل المسح
main

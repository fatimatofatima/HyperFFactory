#!/bin/bash
set -euo pipefail

echo "=== مراقبة حالة SmartFriend Suite ==="
echo "🕒 آخر تحديث: $(date)"
echo ""

# حالة النظام العام
echo "📊 الحالة العامة:"
systemctl list-units "sf-*" "smartfrind-*" --no-legend | \
    awk '
    BEGIN { active=0; failed=0; inactive=0 }
    /active/ && !/failed/ { active++ }
    /failed/ { failed++ }
    /inactive/ { inactive++ }
    END {
        printf "  🟢 نشط: %d\n", active
        printf "  🔴 فاشل: %d\n", failed  
        printf "  ⚫ معطل: %d\n", inactive
    }'

echo ""
echo "🔍 الخدمات الفاشلة (تحتاج انتباه):"
systemctl list-units "sf-*" "smartfrind-*" --state=failed --no-legend --no-pager

echo ""
echo "💾 استخدام الموارد:"
ps aux | grep -E "(smartfriend|sf-)" | grep -v grep | grep -v ffactory | \
    awk '
    BEGIN { cpu=0; mem=0; count=0 }
    { cpu+=$3; mem+=$4; count++ }
    END {
        if (count > 0) {
            printf "  📊 عدد العمليات: %d\n", count
            printf "  🚀 إجمالي CPU: %.1f%%\n", cpu
            printf "  💾 إجمالي RAM: %.1f%%\n", mem
        } else {
            printf "  ℹ️  لا توجد عمليات نشطة\n"
        }
    }'

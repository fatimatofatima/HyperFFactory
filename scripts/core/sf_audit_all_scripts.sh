#!/bin/bash
echo "========================================"
echo " 🔍 فحص شامل لجميع سكربتات SmartFriend"
echo "========================================"

# 1) فحص سكربتات /root
echo "1. سكربتات /root:"
echo "-----------------"
ROOT_SCRIPTS=$(ls -la /root/sf_*.sh 2>/dev/null | wc -l)
echo "   📊 عدد السكربتات: $ROOT_SCRIPTS"
echo "   📋 قائمة السكربتات:"
for script in /root/sf_*.sh; do
    if [ -f "$script" ]; then
        size=$(stat -c%s "$script")
        lines=$(wc -l < "$script")
        echo "   • $(basename $script) - $lines سطر - $size بايت"
    fi
done

# 2) فحص سكربتات النظام
echo
echo "2. سكربتات النظام في /opt/smartfriend-suite:"
echo "--------------------------------------------"
find /opt/smartfriend-suite -name "*.sh" -type f | head -20 | while read script; do
    if [ -f "$script" ]; then
        size=$(stat -c%s "$script")
        lines=$(wc -l < "$script")
        echo "   • ${script#/opt/smartfriend-suite/} - $lines سطر"
    fi
done

# 3) فحص سكربتات العنكبوت
echo
echo "3. سكربتات العنكبوت:"
echo "-------------------"
SPIDER_SCRIPTS=$(find /opt/smartfriend-suite -name "*spider*" -type f | grep -E "\.(sh|py)$")
echo "$SPIDER_SCRIPTS" | while read script; do
    if [ -f "$script" ]; then
        echo "   • ${script#/opt/smartfriend-suite/}"
    fi
done

# 4) فحص حالة الخدمات
echo
echo "4. حالة الخدمات الحالية:"
echo "-----------------------"
systemctl list-units 'sf-*' --no-legend | while read unit load active sub desc; do
    if [ "$active" = "active" ] && [ "$sub" = "running" ]; then
        echo "   ✅ $unit"
    else
        echo "   ❌ $unit - $active/$sub"
    fi
done

# 5) فحص البورتات
echo
echo "5. البورتات النشطة:"
echo "------------------"
ss -tlnp | grep -E ':(8211|8214|8215|8220|8390)' | while read line; do
    echo "   📡 $line"
done

echo
echo "========================================"
echo " 📊 التقرير النهائي:"
echo "========================================"
echo "• سكربتات /root: $ROOT_SCRIPTS"
echo "• الخدمات النشطة: $(systemctl list-units 'sf-*' --state=running --no-legend | wc -l)"
echo "• البورتات النشطة: $(ss -tlnp | grep -E ':(8211|8214|8215|8220|8390)' | wc -l)"
echo "========================================"

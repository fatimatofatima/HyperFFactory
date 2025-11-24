#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=================================================="
echo "           🔴 الخدمات الغير نشطة والفاشلة"
echo "=================================================="
echo

# 1) الخدمات الفاشلة (FAILED)
echo -e "${RED}🚨 الخدمات الفاشلة (FAILED):${NC}"
echo "--------------------------------------------------"
systemctl list-units --state=failed --no-legend | while read unit load active sub desc; do
    if [[ "$active" == "failed" ]]; then
        unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
        echo -e "${RED}❌ $unit${NC}"
        echo "   📍 الموقع: ${unit_file:-غير معروف}"
        echo "   📝 الوصف: $desc"
        echo "   🔍 الحالة: $active ($sub)"
        
        # عرض آخر خطأ من السجلات
        echo "   📋 آخر خطأ:"
        journalctl -u "$unit" -n 3 --no-pager 2>/dev/null | tail -1 | sed 's/^/      /'
        echo
    fi
done

# 2) الخدمات في حالة activating (مشاكل في التشغيل)
echo -e "${YELLOW}🔄 الخدمات في حالة إعادة تشغيل (activating):${NC}"
echo "--------------------------------------------------"
systemctl list-units --state=activating --no-legend | grep -E "(sf-|smartfriend|ff-)" | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    echo -e "${YELLOW}🔄 $unit${NC}"
    echo "   📍 الموقع: ${unit_file:-غير معروف}"
    echo "   📝 الوصف: $desc"
    echo "   🔍 الحالة: $active ($sub)"
    
    # عرض آخر محاولة تشغيل
    echo "   📋 آخر محاولة:"
    journalctl -u "$unit" -n 2 --no-pager 2>/dev/null | tail -1 | sed 's/^/      /'
    echo
done

# 3) الخدمات غير النشطة (inactive) من SmartFriend و FFactory
echo -e "${BLUE}⏸️  الخدمات غير النشطة (INACTIVE):${NC}"
echo "--------------------------------------------------"
echo -e "${BLUE}🎯 SmartFriend Suite غير النشطة:${NC}"
systemctl list-units 'sf-*' 'smartfriend-*' --state=inactive --no-legend | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    echo "   ⏸️  $unit"
    echo "      📍 الموقع: ${unit_file:-غير معروف}"
    echo "      📝 الوصف: $desc"
done
echo

echo -e "${BLUE}🏭 FFactory غير النشطة:${NC}"
systemctl list-units 'ff-*' 'factory-*' --state=inactive --no-legend | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    echo "   ⏸️  $unit"
    echo "      📍 الموقع: ${unit_file:-غير معروف}"
    echo "      📝 الوصف: $desc"
done
echo

# 4) الخدمات الميتة (dead)
echo -e "${RED}💀 الخدمات الميتة (DEAD):${NC}"
echo "--------------------------------------------------"
systemctl list-units --state=dead --no-legend | grep -E "(sf-|smartfriend|ff-)" | while read unit load active sub desc; do
    unit_file=$(systemctl show -p FragmentPath "$unit" 2>/dev/null | cut -d= -f2)
    echo -e "${RED}💀 $unit${NC}"
    echo "   📍 الموقع: ${unit_file:-غير معروف}"
    echo "   📝 الوصف: $desc"
done

# 5) إحصائية نهائية
echo
echo "=================================================="
echo "           📊 إحصائية الخدمات المعطلة"
echo "=================================================="

failed_count=$(systemctl list-units --state=failed | grep -c "failed")
activating_count=$(systemctl list-units --state=activating | grep -E "(sf-|smartfriend|ff-)" | wc -l)
inactive_count=$(systemctl list-units 'sf-*' 'smartfriend-*' 'ff-*' 'factory-*' --state=inactive --no-legend | wc -l)
dead_count=$(systemctl list-units --state=dead | grep -E "(sf-|smartfriend|ff-)" | wc -l)

echo "🔴 الخدمات الفاشلة: $failed_count"
echo "🔄 الخدمات في إعادة تشغيل: $activating_count" 
echo "⏸️  الخدمات غير النشطة: $inactive_count"
echo "💀 الخدمات الميتة: $dead_count"
echo

# 6) توصيات الإصلاح
echo "=================================================="
echo "           🔧 توصيات سريعة للإصلاح"
echo "=================================================="

if [[ $failed_count -gt 0 ]]; then
    echo "🔴 للخدمات الفاشلة:"
    echo "   systemctl reset-failed <service>"
    echo "   journalctl -u <service> -n 20"
    echo
fi

if [[ $activating_count -gt 0 ]]; then
    echo "🔄 للخدمات في إعادة تشغيل:"
    echo "   systemctl stop <service>"
    echo "   systemctl status <service>"
    echo "   فحص ملفات الإعدادات والتبعيات"
    echo
fi

echo "📋 لفحص خدمة محددة:"
echo "   systemctl status <service-name>"
echo "   journalctl -u <service-name> -f"

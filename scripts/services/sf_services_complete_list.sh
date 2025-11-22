#!/usr/bin/env bash

echo "📋 قائمة خدمات SmartFriend/SmartFrind الكاملة (مرقمة ومنظمة)"
echo "==========================================================="
echo

# دالة لاستخراج معلومات الخدمة
get_service_info() {
    local service=$1
    local status=$(systemctl is-active "$service" 2>/dev/null || echo "unknown")
    local enabled=$(systemctl is-enabled "$service" 2>/dev/null || echo "unknown")
    local description=$(systemctl show -p Description "$service" 2>/dev/null | cut -d= -f2)
    
    # الحصول على المسار
    local exec_start=$(systemctl show -p ExecStart "$service" 2>/dev/null | cut -d= -f2 | head -1)
    local pid=$(systemctl show -p MainPID "$service" 2>/dev/null | cut -d= -f2)
    local path=""
    
    if [ "$pid" -ne 0 ] 2>/dev/null; then
        path=$(readlink -f "/proc/$pid/exe" 2>/dev/null || echo "")
        if [ -z "$path" ]; then
            path=$(ps -p $pid -o cmd --no-headers 2>/dev/null | awk '{print $1}' || echo "")
        fi
    fi
    
    echo "$status|$enabled|$description|$exec_start|$path"
}

# ألوان للحالة
print_status() {
    case $1 in
        "active") echo -e "🟢 active" ;;
        "failed") echo -e "🔴 failed" ;;
        "inactive") echo -e "⚪ inactive" ;;
        "activating") echo -e "🟡 activating" ;;
        *) echo -e "⚫ $1" ;;
    esac
}

print_enabled() {
    case $1 in
        "enabled") echo -e "✅ enabled" ;;
        "disabled") echo -e "❌ disabled" ;;
        "static") echo -e "🔵 static" ;;
        "masked") echo -e "🚫 masked" ;;
        *) echo -e "⚫ $1" ;;
    esac
}

# الحصول على جميع خدمات السيوت
echo "🔍 جاري جمع معلومات الخدمات..."
services=$(systemctl list-unit-files "sf-*" "smartfrind-*" "smartfriend-*" --no-legend | awk '{print $1}' | grep -E "\.service$")

counter=1

# خدمات النواة الأساسية
echo "1️⃣ خدمات النواة الأساسية (Core Services):"
echo "----------------------------------------"
core_services=("sf-core.service" "smartfrind-api.service" "smartfrind-core.service" "sf-unified.service")
for service in "${core_services[@]}"; do
    if echo "$services" | grep -q "$service"; then
        IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
        echo "$counter. $service:"
        echo "   📝 الوصف: $description"
        echo "   🎯 الحالة: $(print_status "$status")"
        echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
        echo "   🚀 المسار: $path"
        echo "   💻 التشغيل: $exec_start"
        echo
        ((counter++))
    fi
done

# خدمات البوتات
echo "2️⃣ خدمات البوتات (Bot Services):"
echo "-------------------------------"
bot_services=($(echo "$services" | grep -E "sf-.*bot|telegram" | sort))
for service in "${bot_services[@]}"; do
    IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
    echo "$counter. $service:"
    echo "   📝 الوصف: $description"
    echo "   🎯 الحالة: $(print_status "$status")"
    echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
    echo "   🚀 المسار: $path"
    echo
    ((counter++))
done

# خدمات التعلم والذاكرة
echo "3️⃣ خدمات التعلم والذاكرة (Learning & Memory):"
echo "--------------------------------------------"
learning_services=($(echo "$services" | grep -E "learn|memory|train|ingest" | sort))
for service in "${learning_services[@]}"; do
    IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
    echo "$counter. $service:"
    echo "   📝 الوصف: $description"
    echo "   🎯 الحالة: $(print_status "$status")"
    echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
    echo "   🚀 المسار: $path"
    echo
    ((counter++))
done

# خدمات الصيانة والنسخ الاحتياطي
echo "4️⃣ خدمات الصيانة والنسخ الاحتياطي (Maintenance & Backup):"
echo "-------------------------------------------------------"
maintenance_services=($(echo "$services" | grep -E "backup|db-|maintain|clean" | sort))
for service in "${maintenance_services[@]}"; do
    IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
    echo "$counter. $service:"
    echo "   📝 الوصف: $description"
    echo "   🎯 الحالة: $(print_status "$status")"
    echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
    echo "   🚀 المسار: $path"
    echo
    ((counter++))
done

# خدمات البوابات والواجهات
echo "5️⃣ خدمات البوابات والواجهات (Gateways & APIs):"
echo "---------------------------------------------"
gateway_services=($(echo "$services" | grep -E "api|gateway|web" | sort))
for service in "${gateway_services[@]}"; do
    IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
    echo "$counter. $service:"
    echo "   📝 الوصف: $description"
    echo "   🎯 الحالة: $(print_status "$status")"
    echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
    echo "   🚀 المسار: $path"
    echo
    ((counter++))
done

# الخدمات المتبقية
echo "6️⃣ خدمات أخرى (Other Services):"
echo "-----------------------------"
other_services=($(echo "$services" | grep -vE "bot|learn|memory|backup|api|gateway|web|core" | sort))
for service in "${other_services[@]}"; do
    IFS='|' read -r status enabled description exec_start path <<< "$(get_service_info "$service")"
    echo "$counter. $service:"
    echo "   📝 الوصف: $description"
    echo "   🎯 الحالة: $(print_status "$status")"
    echo "   ⚙️  التفعيل: $(print_enabled "$enabled")"
    echo "   🚀 المسار: $path"
    echo
    ((counter++))
done

# الإحصائيات
total_services=$(echo "$services" | wc -w)
active_services=$(systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --state=active --no-legend 2>/dev/null | wc -l)
failed_services=$(systemctl list-units "sf-*" "smartfrind-*" "smartfriend-*" --state=failed --no-legend 2>/dev/null | wc -l)

echo "📊 إحصائيات الخدمات:"
echo "==================="
echo "• إجمالي خدمات السيوت: $total_services"
echo "• الخدمات النشطة: $active_services"
echo "• الخدمات الفاشلة: $failed_services"
echo "• الخدمات المعطلة: $((total_services - active_services - failed_services))"

echo
echo "💡 ملاحظة: هذه القائمة تشمل جميع خدمات SmartFriend/SmartFrind/sf-* الموجودة على النظام"

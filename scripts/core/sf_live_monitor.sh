#!/bin/bash
echo "🔍 SmartFriend Suite - نظام المراقبة الحية"
echo "⏰ آخر تحديث: $(date)"
echo ""

# حالة الخدمات الأساسية
echo "🎯 الخدمات الأساسية:"
services=("sf-core.service" "sf-unified.service" "sf-memory.service" "sf-web.service" "sf-bot.service" "sf-health.service")
for service in "${services[@]}"; do
    status=$(systemctl is-active "$service" 2>/dev/null || echo "not-found")
    case $status in
        "active") icon="✅" ;;
        "failed") icon="❌" ;;
        "activating") icon="🔄" ;;
        "inactive") icon="⏸️" ;;
        *) icon="❓" ;;
    esac
    echo "   $icon $service: $status"
done

echo ""
echo "🔌 البورتات الحرجة:"
ports=("8210" "8211" "8214" "8220" "8383" "8390")
for port in "${ports[@]}"; do
    if ss -tulpn | grep -q ":$port "; then
        process=$(ss -tulpn | grep ":$port " | awk '{print $7}' | cut -d'"' -f2)
        echo "   ✅ :$port - $process"
    else
        echo "   ❌ :$port - غير نشط"
    fi
done

echo ""
echo "🤖 البوتات النشطة:"
bot_count=$(systemctl list-units "sf-bot*" --no-legend --state=active | wc -l)
echo "   عدد البوتات النشطة: $bot_count"
systemctl list-units "sf-bot*" --no-legend --state=active | head -3 | awk '{print "   🤖 " $1}'

echo ""
echo "📈 الإحصائيات:"
sf_active=$(systemctl list-units "sf-*" --no-legend --state=active | wc -l)
sf_total=$(systemctl list-unit-files "sf-*" --no-legend | wc -l)
legacy_active=$(systemctl list-units "smartfrind-*" --no-legend --state=active | wc -l)

echo "   خدمات sf نشطة: $sf_active/$sf_total"
echo "   خدمات legacy نشطة: $legacy_active"
echo "   التقدم: $(( (sf_active * 100) / (sf_total + 1) ))%"

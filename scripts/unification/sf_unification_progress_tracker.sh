#!/bin/bash

# سكربت متابعة تقدم التوحيد - إصدار متقدم
TS="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="/opt/smartfriend-suite/reports"
PROGRESS_FILE="$REPORT_DIR/sf_unification_progress_${TS}.txt"

mkdir -p "$REPORT_DIR"

log() { 
    echo "[$(date '+%F %T')] $*"
    echo "[$(date '+%F %T')] $*" >> "$PROGRESS_FILE"
}

print_header() {
    echo "============================================================"
    echo " SmartFriend Suite - تقدم عملية التوحيد"
    echo " Timestamp: $(date '+%F %T')"
    echo "============================================================"
}

print_section() {
    echo
    echo "🏷️  $1"
    echo "------------------------------------------------------------"
}

# دالة حساب النسبة المئوية
calculate_percentage() {
    local current=$1
    local total=$2
    if [ $total -eq 0 ]; then
        echo "0"
    else
        echo $(( (current * 100) / total ))
    fi
}

# جمع الإحصائيات الأساسية
collect_stats() {
    # عدد الخدمات النشطة
    SF_ACTIVE=$(systemctl list-units "sf-*" --no-legend 2>/dev/null | grep -c "running")
    SF_TOTAL=$(systemctl list-unit-files "sf-*" --no-legend 2>/dev/null | wc -l)
    
    LEGACY_ACTIVE=$(systemctl list-units "smartfrind-*" --no-legend 2>/dev/null | grep -c "running")
    LEGACY_TOTAL=$(systemctl list-unit-files "smartfrind-*" --no-legend 2>/dev/null | wc -l)
    
    # البورتات
    PORTS_SF=$(ss -tulpn 2>/dev/null | grep -E '(:8210|:8211|:8220|:8214|:8390)' | grep -c "sf-")
    PORTS_LEGACY=$(ss -tulpn 2>/dev/null | grep -E '(:8210|:8211|:8220|:8214|:8390)' | grep -c "smartfrind")
    
    # الخدمات الحرجة
    CRITICAL_SERVICES=("sf-core.service" "sf-unified.service" "sf-memory.service" "sf-web.service" "sf-health.service")
    CRITICAL_WORKING=0
    
    for service in "${CRITICAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ((CRITICAL_WORKING++))
        fi
    done
}

# عرض التقرير
generate_report() {
    print_header
    
    print_section "📊 الإحصائيات العامة"
    echo "✅ خدمات SmartFriend Suite النشطة: $SF_ACTIVE/$SF_TOTAL ($(calculate_percentage $SF_ACTIVE $SF_TOTAL)%)"
    echo "📦 خدمات Legacy النشطة: $LEGACY_ACTIVE/$LEGACY_TOTAL ($(calculate_percentage $LEGACY_ACTIVE $LEGACY_TOTAL)%)"
    echo "🔌 البورتات المشغولة بالسيوت: $PORTS_SF"
    echo "🔌 البورتات المشغولة بالـ Legacy: $PORTS_LEGACY"
    echo "🎯 الخدمات الحرجة العاملة: $CRITICAL_WORKING/${#CRITICAL_SERVICES[@]}"
    
    print_section "🎯 الخدمات الحرجة - حالة التشغيل"
    for service in "${CRITICAL_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo "   ✅ $service - نشط"
        elif systemctl is-failed --quiet "$service" 2>/dev/null; then
            echo "   ❌ $service - فشل"
        else
            echo "   ⏸️  $service - غير نشط"
        fi
    done
    
    print_section "🔄 البورتات الرئيسية - ملكية التشغيل"
    for port in 8210 8211 8220 8214 8390; do
        owner=$(ss -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'"' -f2 || echo "لا أحد")
        echo "   :$port - $owner"
    done
    
    print_section "📈 تقدم التوحيد حسب المجالات"
    
    # 1. مجال API والبوابات
    API_SERVICES=("sf-core.service" "sf-unified.service" "sf-memory.service")
    API_WORKING=0
    for service in "${API_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ((API_WORKING++))
        fi
    done
    echo "   🌐 واجهات API: $API_WORKING/${#API_SERVICES[@]} ($(calculate_percentage $API_WORKING ${#API_SERVICES[@]})%)"
    
    # 2. مجال البوتات
    BOT_SERVICES=$(systemctl list-units "sf-*bot*" "sf-*telegram*" --no-legend 2>/dev/null | grep "running" | wc -l)
    BOT_TOTAL=$(systemctl list-unit-files "sf-*bot*" "sf-*telegram*" --no-legend 2>/dev/null | wc -l)
    echo "   🤖 البوتات: $BOT_SERVICES/$BOT_TOTAL ($(calculate_percentage $BOT_SERVICES $BOT_TOTAL)%)"
    
    # 3. مجال المعرفة والذكاء
    BRAIN_SERVICES=("sf-ingest.service" "sf-kb-build.service" "sf-learn.service" "sf-learning.service" "sf-spider.service")
    BRAIN_WORKING=0
    for service in "${BRAIN_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ((BRAIN_WORKING++))
        fi
    done
    echo "   🧠 أنظمة الذكاء: $BRAIN_WORKING/${#BRAIN_SERVICES[@]} ($(calculate_percentage $BRAIN_WORKING ${#BRAIN_SERVICES[@]})%)"
    
    # 4. مجال المراقبة
    MONITOR_SERVICES=("sf-health.service" "sf-cognitive.service")
    MONITOR_WORKING=0
    for service in "${MONITOR_SERVICES[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            ((MONITOR_WORKING++))
        fi
    done
    echo "   📊 المراقبة: $MONITOR_WORKING/${#MONITOR_SERVICES[@]} ($(calculate_percentage $MONITOR_WORKING ${#MONITOR_SERVICES[@]})%)"
    
    print_section "⚠️  المشاكل الحرجة التي تحتاج علاج"
    
    # فشل الخدمات الحرجة
    for service in "${CRITICAL_SERVICES[@]}"; do
        if systemctl is-failed --quiet "$service" 2>/dev/null; then
            echo "   ❌ $service - فشل في التشغيل"
            # عرض آخر خطأ
            ERROR_MSG=$(sudo journalctl -u "$service" -n 3 --no-pager 2>/dev/null | grep -i "error\|failed\|exception" | head -1 || echo "لا توجد تفاصيل")
            echo "      💡 $ERROR_MSG"
        fi
    done
    
    # ازدواجية البورتات
    for port in 8210 8211 8220; do
        count=$(ss -tulpn 2>/dev/null | grep -c ":$port ")
        if [ $count -gt 1 ]; then
            echo "   🔄 منفذ :$port - ازدواجية ($count خدمات)"
        fi
    done
    
    # خدمات legacy لا تزال نشطة
    if [ $LEGACY_ACTIVE -gt 0 ]; then
        echo "   📦 خدمات Legacy لا تزال نشطة:"
        systemctl list-units "smartfrind-*" --no-legend 2>/dev/null | grep "running" | awk '{print "      - " $1}'
    fi
    
    print_section "🎯 الخطوات التالية المقترحة"
    
    if [ $CRITICAL_WORKING -lt 3 ]; then
        echo "   🔧 الأولوية: إصلاح الخدمات الحرجة المعطلة"
    elif [ $LEGACY_ACTIVE -gt 2 ]; then
        echo "   🚀 التالي: تجميد خدمات Legacy المتبقية"
    elif [ $API_WORKING -eq ${#API_SERVICES[@]} ]; then
        echo "   ✅ الاستعداد: تعديل إعدادات Nginx للتوجيه للسيوت فقط"
    else
        echo "   📝 متابعة: استكمال نقل المنطق المتبقي"
    fi
    
    # حساب النسبة الإجمالية للتقدم
    TOTAL_POSSIBLE=$((SF_TOTAL + ${#CRITICAL_SERVICES[@]} + ${#API_SERVICES[@]} + ${#BRAIN_SERVICES[@]} + ${#MONITOR_SERVICES[@]}))
    TOTAL_ACHIEVED=$((SF_ACTIVE + CRITICAL_WORKING + API_WORKING + BRAIN_WORKING + MONITOR_WORKING))
    OVERALL_PROGRESS=$(calculate_percentage $TOTAL_ACHIEVED $TOTAL_POSSIBLE)
    
    echo
    echo "============================================================"
    echo " 📊 التقدم الكلي: $OVERALL_PROGRESS%"
    echo "============================================================"
    
    # شريط التقدم البصري
    BAR_WIDTH=50
    FILLED=$((OVERALL_PROGRESS * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    
    printf "    ["
    printf "%${FILLED}s" | tr ' ' '█'
    printf "%${EMPTY}s" | tr ' ' '░'
    printf "] %d%%\n" $OVERALL_PROGRESS
    
    echo
    echo "📁 التقرير مفصل في: $PROGRESS_FILE"
}

# التنفيذ الرئيسي
main() {
    log "بدء جمع إحصائيات التقدم..."
    collect_stats
    generate_report | tee -a "$PROGRESS_FILE"
    
    # حفظ الإحصائيات للمقارنة لاحقاً
    echo "$TS|$SF_ACTIVE|$SF_TOTAL|$LEGACY_ACTIVE|$LEGACY_TOTAL|$CRITICAL_WORKING" >> "$REPORT_DIR/sf_progress_history.csv"
    
    log "تم إنشاء تقرير التقدم"
}

main

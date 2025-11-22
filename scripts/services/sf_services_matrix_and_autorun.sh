#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){ echo; echo "======= $1 ======="; }

AUDIT_DIR="/root/services_matrix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$AUDIT_DIR"

log "===== 🗂️ Phase D: Service Matrix + Autorun ====="

# 1. جمع كل الخدمات الفعلية
section "1. جمع الخدمات الفعلية من systemd"

systemctl list-unit-files 'sf-*' 'ff-*' > "$AUDIT_DIR/all_unit_files.txt"

# وظيفة لتحليل كل خدمة
analyze_service() {
    local service="$1"
    local file="$AUDIT_DIR/service_${service}.analysis"
    
    echo "=== $service ===" > "$file"
    
    # المعلومات الأساسية
    echo "Active: $(systemctl is-active "$service" 2>/dev/null || echo 'unknown')" >> "$file"
    echo "Enabled: $(systemctl is-enabled "$service" 2>/dev/null || echo 'unknown')" >> "$file"
    
    # المسار الفعلي
    local fragment_path=$(systemctl show "$service" -p FragmentPath --value 2>/dev/null)
    if [ -n "$fragment_path" ] && [ "$fragment_path" != "(null)" ]; then
        echo "FragmentPath: $fragment_path" >> "$file"
    else
        echo "FragmentPath: ❌ غير موجود" >> "$file"
    fi
    
    # ExecStart
    local exec_start=$(systemctl show "$service" -p ExecStart --value 2>/dev/null)
    echo "ExecStart: $exec_start" >> "$file"
    
    # تصنيف المسار
    if [[ "$exec_start" == *"/opt/smartfriend-suite"* ]]; then
        echo "Family: smartfriend-suite" >> "$file"
        echo "RootPath: /opt/smartfriend-suite" >> "$file"
    elif [[ "$exec_start" == *"/opt/ffactory"* ]]; then
        echo "Family: ffactory" >> "$file" 
        echo "RootPath: /opt/ffactory" >> "$file"
    else
        echo "Family: other" >> "$file"
        echo "RootPath: -" >> "$file"
    fi
    
    # التصنيف الوظيفي
    classify_functional "$service" "$exec_start" >> "$file"
}

# وظيفة التصنيف الوظيفي
classify_functional() {
    local service="$1"
    local exec="$2"
    
    case "$service" in
        *health*) echo "Functional: الصحة والمراقبة" ;;
        *memory*) echo "Functional: الذاكرة والمعرفة" ;;
        *unified*) echo "Functional: الواجهات الموحدة" ;;
        *bot*) echo "Functional: البوتات والتكامل" ;;
        *telegram*) echo "Functional: البوتات والتكامل" ;;
        *cognitive*) echo "Functional: النواة الذكية" ;;
        *learn*) echo "Functional: التعلم والتدريب" ;;
        *ingest*) echo "Functional: استيعاب البيانات" ;;
        *spider*) echo "Functional: جمع البيانات" ;;
        *factory*) echo "Functional: المصانع الذكية" ;;
        *core*) echo "Functional: النواة الأساسية" ;;
        *web*) echo "Functional: الواجهات الويب" ;;
        *backup*) echo "Functional: النسخ الاحتياطي" ;;
        *audit*) echo "Functional: التدقيق والمراجعة" ;;
        *doctor*) echo "Functional: التشخيص والإصلاح" ;;
        *board*) echo "Functional: لوحات التحكم" ;;
        *) 
            if [[ "$exec" == *"/opt/smartfriend-suite"* ]]; then
                echo "Functional: خدمات SmartFriend عامة"
            elif [[ "$exec" == *"/opt/ffactory"* ]]; then
                echo "Functional: خدمات FFactory عامة" 
            else
                echo "Functional: خدمات خارجية"
            fi
            ;;
    esac
}

# تحليل جميع الخدمات
services=$(systemctl list-unit-files 'sf-*' 'ff-*' --no-legend | awk '{print $1}')
log "تحليل ${#services[@]} خدمة..."

for service in $services; do
    log "🔍 تحليل: $service"
    analyze_service "$service"
done

section "2. إنشاء المصفوفة الشاملة"

# إنشاء تقرير مصفوفي
cat > "$AUDIT_DIR/services_matrix.csv" <<'CSVHEADER'
Service,Active,Enabled,Family,Functional,FragmentPath,ExecStart
CSVHEADER

for service in $services; do
    analysis_file="$AUDIT_DIR/service_${service}.analysis"
    if [ -f "$analysis_file" ]; then
        active=$(grep "Active:" "$analysis_file" | cut -d: -f2 | xargs)
        enabled=$(grep "Enabled:" "$analysis_file" | cut -d: -f2 | xargs)
        family=$(grep "Family:" "$analysis_file" | cut -d: -f2 | xargs)
        functional=$(grep "Functional:" "$analysis_file" | cut -d: -f2 | xargs)
        fragment=$(grep "FragmentPath:" "$analysis_file" | cut -d: -f2- | xargs)
        exec_start=$(grep "ExecStart:" "$analysis_file" | cut -d: -f2- | xargs | cut -c1-50)
        
        echo "\"$service\",\"$active\",\"$enabled\",\"$family\",\"$functional\",\"$fragment\",\"$exec_start\"" >> "$AUDIT_DIR/services_matrix.csv"
    fi
done

section "3. تصنيف حسب الطبقات الوظيفية"

declare -A layers

# طبقات الأعمال الرئيسية
layers=(
    ["النواة الذكية"]=""
    ["الذاكرة والمعرفة"]=""
    ["البوتات والتكامل"]=""
    ["جمع البيانات"]=""
    ["التعلم والتدريب"]=""
    ["المصانع الذكية"]=""
    ["النسخ الاحتياطي"]=""
    ["التدقيق والمراجعة"]=""
)

# توزيع الخدمات على الطبقات
for service in $services; do
    analysis_file="$AUDIT_DIR/service_${service}.analysis"
    if [ -f "$analysis_file" ]; then
        functional=$(grep "Functional:" "$analysis_file" | cut -d: -f2 | xargs)
        active=$(grep "Active:" "$analysis_file" | cut -d: -f2 | xargs)
        
        # إيجاد الطبقة المناسبة
        layer="خدمات عامة"
        for key in "${!layers[@]}"; do
            if [[ "$functional" == *"$key"* ]]; then
                layer="$key"
                break
            fi
        done
        
        # إضافة الخدمة للطبقة مع حالةها
        status_icon="🟢"
        [ "$active" != "active" ] && status_icon="🔴"
        [ "$active" == "inactive" ] && status_icon="🟡"
        
        layers["$layer"]+=" $status_icon $service"
    fi
done

# عرض الطبقات
echo "🏗️  هيكل الطبقات الوظيفية:" > "$AUDIT_DIR/functional_layers.txt"
for layer in "${!layers[@]}"; do
    count=$(echo "${layers[$layer]}" | wc -w)
    echo "   $layer: $((count/2)) خدمة" >> "$AUDIT_DIR/functional_layers.txt"
    echo "${layers[$layer]}" | tr ' ' '\n' | grep -v '^$' | sed 's/^/      /' >> "$AUDIT_DIR/functional_layers.txt"
    echo >> "$AUDIT_DIR/functional_layers.txt"
done

section "4. أوامر التشغيل الذاتي المنظم"

# إنشاء أوامر التشغيل حسب البروفايل
cat > "$AUDIT_DIR/autorun_profiles.sh" <<'PROFILES'
#!/bin/bash

# بروفايلات التشغيل التلقائي
brain_only() {
    echo "🧠 تشغيل النواة الذكية فقط"
    systemctl restart sf-health.service
    systemctl restart sf-memory.service
    systemctl restart sf-unified.service
    systemctl restart ff-healthd.service
}

suite_core() {
    echo "🏗️ تشغيل السويت الأساسي"
    brain_only
    systemctl restart sf-bot.service 2>/dev/null || echo "⚠️  sf-bot.service غير قابل للتشغيل"
    systemctl restart sf-telegram.service 2>/dev/null || echo "⚠️  sf-telegram.service غير قابل للتشغيل"
    systemctl restart sf-learning.service 2>/dev/null || echo "⚠️  sf-learning.service غير قابل للتشغيل"
    systemctl restart sf-spider.service 2>/dev/null || echo "⚠️  sf-spider.service غير قابل للتشغيل"
}

full_suite() {
    echo "🎪 تشغيل السويت الكامل"
    suite_core
    # تشغيل كل الخدمات المتاحة
    for service in $(systemctl list-unit-files 'sf-*' 'ff-*' --no-legend | awk '{print $1}'); do
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            echo "   محاولة تشغيل: $service"
            systemctl restart "$service" 2>/dev/null || true
        fi
    done
}

# استعراض الحالة
status_report() {
    echo "📊 تقرير الحالة الحالي:"
    echo "   الخدمات النشطة:"
    systemctl list-units 'sf-*' 'ff-*' --state=running --no-legend | awk '{print "      ✅ " $1}'
    echo "   الخدمات المعطلة:"
    systemctl list-units 'sf-*' 'ff-*' --state=inactive --no-legend | awk '{print "      💤 " $1}'
    echo "   الخدمات الفاشلة:"
    systemctl list-units 'sf-*' 'ff-*' --state=failed --no-legend | awk '{print "      💀 " $1}'
}

case "${1:-status}" in
    brain) brain_only ;;
    suite) suite_core ;;
    full) full_suite ;;
    status) status_report ;;
    *) echo "استخدام: $0 {brain|suite|full|status}" ;;
esac
PROFILES

chmod +x "$AUDIT_DIR/autorun_profiles.sh"

section "5. التقرير النهائي"

# إنشاء التقرير النهائي
cat > "$AUDIT_DIR/final_report.txt" <<'REPORT'
🎯 Phase D: Service Matrix + Autorun - التقرير النهائي
===================================================

📈 الإحصائيات:
• إجمالي الخدمات المحللة: $(echo "$services" | wc -w)
• الخدمات النشطة: $(systemctl list-units 'sf-*' 'ff-*' --state=active --no-legend | wc -l)
• الخدمات المعطلة: $(systemctl list-units 'sf-*' 'ff-*' --state=inactive --no-legend | wc -l)
• الخدمات الفاشلة: $(systemctl list-units 'sf-*' 'ff-*' --state=failed --no-legend | wc -l)

🏗️ الهيكل الوظيفي:
$(cat "$AUDIT_DIR/functional_layers.txt")

🚀 أوامر التشغيل السريع:
• تشغيل النواة فقط:   $AUDIT_DIR/autorun_profiles.sh brain
• تشغيل السويت الأساسي: $AUDIT_DIR/autorun_profiles.sh suite  
• تشغيل السويت الكامل:  $AUDIT_DIR/autorun_profiles.sh full
• عرض الحالة الحالية:  $AUDIT_DIR/autorun_profiles.sh status

📁 الملفات المُنشأة:
• services_matrix.csv - المصفوفة الشاملة للخدمات
• functional_layers.txt - تصنيف الطبقات الوظيفية
• autorun_profiles.sh - أوامر التشغيل التلقائي
• service_*.analysis - التحليل المفصل لكل خدمة

🎪 الخلاصة:
تم بناء نظام تصنيف وتشغيل شامل للخدمات بدون أي symlinks
جميع الأوامر تعتمد على systemd مباشرة وتعمل داخل مسارات السويت الأصلية
REPORT

# عرض التقرير النهائي
cat "$AUDIT_DIR/final_report.txt"

section "6. الاختبار الفوري"

log "اختبار التشغيل الذاتي - النواة الذكية فقط:"
"$AUDIT_DIR/autorun_profiles.sh" brain

sleep 3

log "عرض الحالة النهائية:"
"$AUDIT_DIR/autorun_profiles.sh" status

log "===== ✅ اكتمل Phase D ====="
log "📁 التقرير الكامل في: $AUDIT_DIR"
log "🚀 جاهز للتشغيل المنظم بدون symlinks!"

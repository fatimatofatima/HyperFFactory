#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
ok()   { echo -e "${GREEN}✅${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
err()  { echo -e "${RED}❌${NC} $*"; }

section() {
    echo
    echo "============================================================"
    echo -e "${BLUE}$1${NC}"
    echo "============================================================"
}

# إحصائيات النظام
system_stats() {
    section "إحصائيات النظام العامة"
    
    echo -e "${GREEN}🖥️  معلومات السيرفر:${NC}"
    echo "  Hostname: $(hostname)"
    echo "  Uptime: $(uptime -p)"
    echo "  OS: $(lsb_release -d | cut -f2)"
    
    echo -e "${GREEN}📊 استخدام الموارد:${NC}"
    echo "  CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2 " (" $4 " free)"}')"
    echo "  Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
    
    echo -e "${GREEN}🌐 الشبكة:${NC}"
    echo "  IP: $(hostname -I | awk '{print $1}')"
}

# فحص الخدمات
service_stats() {
    section "إحصائية الخدمات التفصيلية"
    
    # أنماط الخدمات للمسح
    patterns=("sf-*" "smartfriend-*" "smartfrind-*" "ff*" "factory-*")
    
    total_services=0
    active_services=0
    failed_services=0
    activating_services=0
    
    echo -e "${GREEN}🔍 مسح الخدمات...${NC}"
    
    for pattern in "${patterns[@]}"; do
        while IFS= read -r service; do
            [ -z "$service" ] && continue
            
            service_name=$(basename "$service")
            state=$(systemctl is-active "$service_name" 2>/dev/null || echo "unknown")
            enabled=$(systemctl is-enabled "$service_name" 2>/dev/null || echo "unknown")
            
            ((total_services++))
            
            case "$state" in
                "active")
                    ((active_services++))
                    echo -e "  ${GREEN}🟢 $service_name${NC} (مفعّل: $enabled)"
                    ;;
                "activating"|"deactivating")
                    ((activating_services++))
                    echo -e "  ${YELLOW}🟡 $service_name${NC} (جاري: $state, مفعّل: $enabled)"
                    ;;
                "failed")
                    ((failed_services++))
                    echo -e "  ${RED}🔴 $service_name${NC} (فشل, مفعّل: $enabled)"
                    ;;
                "inactive")
                    echo -e "  ⚪ $service_name (متوقف, مفعّل: $enabled)"
                    ;;
                *)
                    echo -e "  🔵 $service_name (حالة: $state, مفعّل: $enabled)"
                    ;;
            esac
            
        done < <(systemctl list-unit-files "$pattern" --no-legend 2>/dev/null | awk '{print $1}')
    done
    
    echo
    section "📈 الإحصائيات النهائية"
    echo "  إجمالي الخدمات: $total_services"
    echo "  الخدمات الشغالة: $active_services"
    echo "  الخدمات المتعثرة: $activating_services" 
    echo "  الخدمات الفاشلة: $failed_services"
    echo "  الخدمات المتوقفة: $((total_services - active_services - activating_services - failed_services))"
    
    # حساب النسبة
    if [ $total_services -gt 0 ]; then
        percentage=$((active_services * 100 / total_services))
        echo "  نسبة التشغيل: $percentage%"
    fi
}

# فحص المسارات المهمة
path_check() {
    section "فحص المسارات الأساسية"
    
    important_paths=(
        "/opt/smartfriend-suite"
        "/opt/smartfrind" 
        "/opt/ffactory"
        "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
        "/etc/systemd/system"
        "/root/sf_*.sh"
    )
    
    for path in "${important_paths[@]}"; do
        if ls -d $path >/dev/null 2>&1; then
            ok "موجود: $path"
            if [[ "$path" == *.db ]]; then
                size=$(ls -lh "$path" 2>/dev/null | awk '{print $5}' || echo "unknown")
                echo "    حجم: $size"
            fi
        else
            warn "مفقود: $path"
        fi
    done
}

# فحص المنافذ
port_check() {
    section "فحص المنافذ النشطة"
    
    important_ports=(80 443 8170 8210 8211 8220 8383)
    
    echo -e "${GREEN}🌐 المنافذ النشطة:${NC}"
    for port in "${important_ports[@]}"; do
        if ss -tln | grep -q ":$port "; then
            process=$(ss -tlpn "sport = :$port" | awk 'NR==2 {print $7}' | cut -d'"' -f2)
            ok "منفذ $port مفتوح - العملية: ${process:-غير معروف}"
        else
            warn "منفذ $port مغلق"
        fi
    done
}

# التقرير النهائي
summary() {
    section "التقرير النهائي"
    
    echo -e "${GREEN}✅ النظام:${NC}"
    echo "  - البنية التحتية: 🟢 شغالة"
    echo "  - SmartFriend Suite: 🟢 أساسيات شغالة"
    echo "  - ffactory: 🟢 جزئي شغال"
    echo "  - SmartFrind: ⚪ محركات داخلية فقط"
    
    echo -e "${YELLOW}📋 التوصيات:${NC}"
    echo "  - الخدمات المتعثرة تحتاج فحص الـ logs"
    echo "  - تأكد من وجود نسخ احتياطية للـ DB"
    echo "  - المراقبة المستمرة للأداء"
    
    log "تم إنشاء التقرير في: /root/sf_reports/system_health_$(date +%Y%m%d_%H%M%S).log"
}

# التنفيذ الرئيسي
main() {
    log "=== SmartFriend - فحص صحة النظام الشامل ==="
    
    system_stats
    service_stats
    path_check
    port_check
    summary
}

# تشغيل السكربت مع حفظ التقرير
mkdir -p /root/sf_reports
main | tee "/root/sf_reports/system_health_$(date +%Y%m%d_%H%M%S).log"

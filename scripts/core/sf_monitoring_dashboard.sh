#!/usr/bin/env bash
set -Eeuo pipefail

# ألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

header() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│              SmartFriend Suite - لوحة المراقبة         │${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────┘${NC}"
    echo -e "⏰ $(date '+%Y-%m-%d %H:%M:%S') | 🔄 للتحديث: اضغط Enter"
    echo
}

show_services_status() {
    echo -e "${CYAN}=== حالة الخدمات ===${NC}"
    
    # خدمات Core
    echo -e "\n${BLUE}🎯 Core Services:${NC}"
    for service in sf-health sf-memory sf-unified; do
        if systemctl is-active "$service.service" >/dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} $service.service"
        else
            echo -e "  ${RED}●${NC} $service.service"
        fi
    done
    
    # خدمات Brain
    echo -e "\n${BLUE}🧠 Brain Stack:${NC}"
    for service in sf-ingest sf-learn sf-learning sf-kb-build sf-fts-maint sf-spider; do
        if systemctl is-active "$service.service" >/dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} $service.service"
        else
            echo -e "  ${RED}●${NC} $service.service"
        fi
    done
    
    # خدمات ffactory
    echo -e "\n${BLUE}🏭 FFactory Services:${NC}"
    for service in ff-doctor ff-healthd ff-selfaware; do
        if systemctl is-active "$service.service" >/dev/null 2>&1; then
            echo -e "  ${GREEN}●${NC} $service.service"
        else
            echo -e "  ${RED}●${NC} $service.service"
        fi
    done
}

show_system_resources() {
    echo -e "\n${CYAN}=== موارد النظام ===${NC}"
    
    # الذاكرة
    memory=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
    echo -e "🧠 الذاكرة: $memory"
    
    # التخزين
    storage=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
    echo -e "💾 التخزين: $storage"
    
    # الحمل
    load=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "⚡ الحمل: $load"
}

show_active_ports() {
    echo -e "\n${CYAN}=== المنافذ النشطة ===${NC}"
    
    ports=$(ss -tlnp | grep -E ':(8210|8214|8220|8330|8390|8170)' | awk '{print $4 " -> " $6}' | head -10)
    if [[ -n "$ports" ]]; then
        echo "$ports"
    else
        echo -e "  ${YELLOW}لا توجد منافذ نشطة${NC}"
    fi
}

show_recent_logs() {
    echo -e "\n${CYAN}=== آخر السجلات ===${NC}"
    
    # آخر سجلات systemd
    logs=$(journalctl -u "sf-*" --since "5 minutes ago" --no-pager | tail -5)
    if [[ -n "$logs" ]]; then
        echo "$logs"
    else
        echo -e "  ${YELLOW}لا توجد سجلات حديثة${NC}"
    fi
}

show_quick_actions() {
    echo -e "\n${CYAN}=== إجراءات سريعة ===${NC}"
    echo -e "1. تشغيل الإصلاح الآلي   2. فحص مفصل   3. تشغيل Brain   4. تشغيل Core"
    echo -e "5. إعادة تحميل systemd   6. عرض السجلات   q. خروج"
}

main() {
    while true; do
        header
        show_services_status
        show_system_resources
        show_active_ports
        show_recent_logs
        show_quick_actions
        
        echo
        read -p "اختر إجراء (Enter للتحديث، q للخروج): " choice
        
        case "$choice" in
            1)
                echo -e "\n${GREEN}تشغيل الإصلاح الآلي...${NC}"
                /root/sf_auto_repair_and_start.sh
                read -p "اضغط Enter للمتابعة..."
                ;;
            2)
                echo -e "\n${GREEN}تشغيل الفحص المفصل...${NC}"
                /root/sf_diagnostic_suite.sh
                read -p "اضغط Enter للمتابعة..."
                ;;
            3)
                echo -e "\n${GREEN}تشغيل Brain Stack...${NC}"
                systemctl start sf-ingest.service sf-learn.service sf-learning.service sf-kb-build.service sf-fts-maint.service
                read -p "اضغط Enter للمتابعة..."
                ;;
            4)
                echo -e "\n${GREEN}تشغيل Core Services...${NC}"
                systemctl start sf-health.service sf-memory.service sf-unified.service
                read -p "اضغط Enter للمتابعة..."
                ;;
            5)
                echo -e "\n${GREEN}إعادة تحميل systemd...${NC}"
                systemctl daemon-reload
                read -p "اضغط Enter للمتابعة..."
                ;;
            6)
                echo -e "\n${GREEN}عرض السجلات...${NC}"
                journalctl -u "sf-*" --since "1 hour ago" --no-pager | less
                ;;
            q|Q)
                echo -e "\n${GREEN}مع السلامة! 👋${NC}"
                break
                ;;
            *)
                # تحديث تلقائي عند الضغط على Enter
                continue
                ;;
        esac
    done
}

main "$@"

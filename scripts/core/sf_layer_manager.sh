#!/bin/bash

# ألوان للواجهة
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "   🎮 SmartFriend Layer Manager"
    echo "=================================================="
    echo -e "${NC}"
}

# إدارة Identity Layer
manage_identity() {
    echo -e "\n${BLUE}🆔 إدارة الهوية (Identity)${NC}"
    
    if [[ -f "/var/lib/smartfrind/smart_memory.db" ]]; then
        records=$(sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM ai_memory;" 2>/dev/null)
        echo -e "  ${GREEN}✅ الهوية نشطة ($records سجل)${NC}"
        
        echo "  الأوامر المتاحة:"
        echo "    1) عرض الإحصائيات"
        echo "    2) نسخ احتياطي"
        echo "    3) العودة"
        
        read -p "  اختر الأمر [1-3]: " choice
        case $choice in
            1)
                echo -e "\n${YELLOW}📊 إحصائيات الهوية:${NC}"
                sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT name FROM sqlite_master WHERE type='table';" 2>/dev/null
                ;;
            2)
                backup_file="/root/identity_backup_$(date +%Y%m%d_%H%M%S).db"
                cp "/var/lib/smartfrind/smart_memory.db" "$backup_file"
                echo -e "  ${GREEN}✅ تم النسخ الاحتياطي إلى: $backup_file${NC}"
                ;;
        esac
    else
        echo -e "  ${RED}❌ الهوية غير مثبتة${NC}"
    fi
}

# إدارة Memory Layer
manage_memory() {
    echo -e "\n${BLUE}🧠 إدارة الذاكرة (Memory)${NC}"
    
    dbs=$(find /opt/smartfriend-suite/var/db -name "*.db" -type f 2>/dev/null)
    if [[ -n "$dbs" ]]; then
        echo -e "  ${GREEN}✅ قواعد الذاكرة مثبتة${NC}"
        for db in $dbs; do
            size=$(stat -c%s "$db" 2>/dev/null || echo "0")
            echo "  📁 $(basename $db) - $(numfmt --to=iec $size)"
        done
        
        echo "  الأوامر المتاحة:"
        echo "    1) فحص النزاهة"
        echo "    2) مزامنة البيانات"
        echo "    3) العودة"
        
        read -p "  اختر الأمر [1-3]: " choice
        case $choice in
            1)
                for db in $dbs; do
                    if sqlite3 "$db" "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
                        echo -e "  ${GREEN}✅ $(basename $db) سليمة${NC}"
                    else
                        echo -e "  ${RED}❌ $(basename $db) معطوبة${NC}"
                    fi
                done
                ;;
            2)
                echo -e "  ${YELLOW}⏳ جاري المزامنة...${NC}"
                # هنا يمكن إضافة كود المزامنة
                ;;
        esac
    else
        echo -e "  ${RED}❌ قواعد الذاكرة غير مثبتة${NC}"
    fi
}

# إدارة Knowledge Layer
manage_knowledge() {
    echo -e "\n${BLUE}📚 إدارة المعرفة (Knowledge)${NC}"
    
    if sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM knowledge_base;" 2>/dev/null | grep -q "[0-9]"; then
        count=$(sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM knowledge_base;" 2>/dev/null)
        echo -e "  ${GREEN}✅ قاعدة المعرفة نشطة ($count عنصر)${NC}"
        
        echo "  الأوامر المتاحة:"
        echo "    1) بحث في المعرفة"
        echo "    2) عرض التصنيفات"
        echo "    3) تحديث الفهرس"
        echo "    4) العودة"
        
        read -p "  اختر الأمر [1-4]: " choice
        case $choice in
            1)
                read -p "  أدخل مصطلح البحث: " term
                results=$(sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT COUNT(*) FROM ai_memory_fts WHERE ai_memory_fts MATCH '$term';" 2>/dev/null)
                echo -e "  ${GREEN}📖 وجد $results نتيجة لـ '$term'${NC}"
                ;;
            2)
                echo -e "\n${YELLOW}🏷️  التصنيفات:${NC}"
                sqlite3 "/var/lib/smartfrind/smart_memory.db" "SELECT category, COUNT(*) FROM ai_memory GROUP BY category ORDER BY COUNT(*) DESC LIMIT 10;" 2>/dev/null
                ;;
            3)
                echo -e "  ${YELLOW}⏳ جاري تحديث الفهرس...${NC}"
                sqlite3 "/var/lib/smartfrind/smart_memory.db" "INSERT INTO ai_memory_fts(ai_memory_fts) VALUES('optimize');" 2>/dev/null
                echo -e "  ${GREEN}✅ تم تحديث الفهرس${NC}"
                ;;
        esac
    else
        echo -e "  ${RED}❌ قاعدة المعرفة غير نشطة${NC}"
    fi
}

# إدارة Learning Layer
manage_learning() {
    echo -e "\n${BLUE}🎓 إدارة التعلم (Learning)${NC}"
    
    if systemctl is-active "smartfrind-learning.service" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✅ محرك التعلم نشط${NC}"
        echo "  الأوامر: [1] إيقاف [2] إعادة تشغيل [3] السجلات [4] العودة"
    elif [[ -f "/opt/smartfrind/continuous_learning.sh" ]]; then
        echo -e "  ${YELLOW}⏸️  محرك التعلم متوقف${NC}"
        echo "  الأوامر: [1] تشغيل [2] حالة [3] العودة"
    else
        echo -e "  ${RED}❌ محرك التعلم غير مثبت${NC}"
        return
    fi
    
    read -p "  اختر الأمر: " choice
    case $choice in
        1)
            if systemctl is-active "smartfrind-learning.service" >/dev/null 2>&1; then
                systemctl stop smartfrind-learning.service
                echo -e "  ${YELLOW}⏹️  تم إيقاف التعلم${NC}"
            else
                systemctl start smartfrind-learning.service
                echo -e "  ${GREEN}▶️  تم تشغيل التعلم${NC}"
            fi
            ;;
        2)
            if systemctl is-active "smartfrind-learning.service" >/dev/null 2>&1; then
                systemctl restart smartfrind-learning.service
                echo -e "  \"🔄 تم إعادة تشغيل التعلم${NC}"
            else
                systemctl status smartfrind-learning.service
            fi
            ;;
        3)
            journalctl -u smartfrind-learning.service -n 10 --no-pager
            ;;
    esac
}

# إدارة Brain Layer
manage_brain() {
    echo -e "\n${BLUE}🤖 إدارة العقل (Brain)${NC}"
    
    apis=()
    for port in 8211 8214 8220; do
        if netstat -tulpn | grep ":$port " >/dev/null; then
            apis+=("$port:🟢")
        else
            apis+=("$port:🔴")
        fi
    done
    
    echo "  واجهات العقل:"
    for api in "${apis[@]}"; do
        IFS=':' read -r port status <<< "$api"
        case $port in
            8211) name="Smart Core API" ;;
            8214) name="Memory API" ;;
            8220) name="Unified API" ;;
        esac
        echo "    $status $name (:$port)"
    done
    
    echo "  الأوامر المتاحة:"
    echo "    1) تشغيل جميع الواجهات"
    echo "    2) إيقاف جميع الواجهات"
    echo "    3) فحص الصحة"
    echo "    4) العودة"
    
    read -p "  اختر الأمر [1-4]: " choice
    case $choice in
        1)
            echo -e "  ${YELLOW}⏳ جاري تشغيل الواجهات...${NC}"
            systemctl start smartfriend-smartcore.service
            systemctl start smartfriend-unified.service
            ;;
        2)
            echo -e "  ${YELLOW}⏳ جاري إيقاف الواجهات...${NC}"
            systemctl stop smartfriend-smartcore.service
            systemctl stop smartfriend-unified.service
            ;;
        3)
            for port in 8211 8214 8220; do
                if curl -s http://localhost:$port/docs >/dev/null 2>&1; then
                    echo -e "  ${GREEN}✅ :$port - صحي${NC}"
                else
                    echo -e "  ${RED}❌ :$port - غير مستجيب${NC}"
                fi
            done
            ;;
    esac
}

# القائمة الرئيسية
main_menu() {
    while true; do
        show_header
        echo "الطبقات المتاحة:"
        echo "  1) 🆔 الهوية (Identity)"
        echo "  2) 🧠 الذاكرة (Memory)" 
        echo "  3) 📚 المعرفة (Knowledge)"
        echo "  4) 🎓 التعلم (Learning)"
        echo "  5) 🤖 العقل (Brain)"
        echo "  6) 📊 Dashboard سريع"
        echo "  7) 🚪 خروج"
        
        read -p "اختر الطبقة [1-7]: " choice
        case $choice in
            1) manage_identity ;;
            2) manage_memory ;;
            3) manage_knowledge ;;
            4) manage_learning ;;
            5) manage_brain ;;
            6) ./sf_dashboard.sh ;;
            7) 
                echo -e "${GREEN}مع السلامة! 👋${NC}"
                exit 0
                ;;
            *) echo -e "${RED}اختيار غير صحيح!${NC}" ;;
        esac
        
        echo ""
        read -p "اضغط Enter للمتابعة..."
    done
}

# بدء البرنامج
main_menu

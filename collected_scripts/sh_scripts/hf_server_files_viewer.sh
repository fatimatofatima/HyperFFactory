#!/bin/bash
echo "📁 عارض ملفات السيرفر - Hyper Factory"
echo "==================================="

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# إحصائيات سريعة
show_quick_stats() {
    echo -e "${CYAN}📊 إحصائيات سريعة:${NC}"
    echo -e "${YELLOW}• ${NC}المسار الحالي: $(pwd)"
    echo -e "${YELLOW}• ${NC}المساحة: $(df -h . | awk 'NR==2{print $4 " متاحة"}')"
    echo -e "${YELLOW}• ${NC}الذاكرة: $(free -h | awk 'NR==2{print $3 " مستخدمة من " $2}')"
    echo ""
}

# عرض الملفات حسب النوع
show_files_by_type() {
    local dir="${1:-.}"
    
    echo -e "${GREEN}📂 محتويات: $dir${NC}"
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────┐${NC}"
    
    # Python files
    py_count=$(find "$dir" -name "*.py" -type f 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ 🐍 Python:${NC} $py_count ملف"
    
    # Shell scripts
    sh_count=$(find "$dir" -name "*.sh" -type f 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ 🐚 Shell:${NC} $sh_count سكربت"
    
    # Config files
    json_count=$(find "$dir" -name "*.json" -type f 2>/dev/null | wc -l)
    yaml_count=$(find "$dir" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ ⚙️  Config:${NC} $json_count JSON, $yaml_count YAML"
    
    # Databases
    db_count=$(find "$dir" -name "*.db" -o -name "*.sqlite" 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ 🗃️  Databases:${NC} $db_count قاعدة"
    
    # Docker files
    docker_count=$(find "$dir" -name "docker-compose*.yml" -type f 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ 🐳 Docker:${NC} $docker_count ملف"
    
    # Markdown docs
    md_count=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l)
    echo -e "${YELLOW}│ 📝 Docs:${NC} $md_count ملف توثيق"
    
    echo -e "${CYAN}└────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# عرض أكبر المجلدات
show_largest_dirs() {
    local dir="${1:-.}"
    
    echo -e "${PURPLE}🏆 أكبر 10 مجلدات:${NC}"
    du -sh "$dir"/* 2>/dev/null | sort -hr | head -10 | while read size path; do
        echo -e "  ${GREEN}$size${NC} ${YELLOW}$(basename "$path")${NC}"
    done
    echo ""
}

# عرض أحدث الملفات
show_recent_files() {
    local dir="${1:-.}"
    
    echo -e "${BLUE}🕐 أحدث 10 ملفات:${NC}"
    find "$dir" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -10 | \
    while read time file; do
        date=$(date -d "@$time" "+%Y-%m-%d %H:%M:%S")
        echo -e "  ${CYAN}$date${NC} ${YELLOW}$(basename "$file")${NC}"
    done
    echo ""
}

# عرض هيكل المجلدات
show_directory_tree() {
    local dir="${1:-.}"
    local depth="${2:-2}"
    
    echo -e "${GREEN}🌳 هيكل المجلدات (عمق $depth):${NC}"
    tree "$dir" -L "$depth" -d 2>/dev/null | head -20
    if [ $? -ne 0 ]; then
        find "$dir" -maxdepth "$depth" -type d 2>/dev/null | head -20 | while read d; do
            level=$(echo "$d" | tr -cd '/' | wc -c)
            indent=$(printf "%${level}s" " ")
            echo -e "${PURPLE}${indent}📁 $(basename "$d")${NC}"
        done
    fi
    echo ""
}

# البحث عن ملفات مهمة
find_important_files() {
    local dir="${1:-.}"
    
    echo -e "${RED}🔍 ملفات مهمة:${NC}"
    
    # سكربتات التشغيل الرئيسية
    echo -e "${YELLOW}🎯 سكربتات التشغيل:${NC}"
    find "$dir" -name "*.sh" -type f 2>/dev/null | grep -E "(run|start|main|init)" | head -5 | while read file; do
        echo -e "  ${GREEN}▶ ${NC}$file"
    done
    
    # ملفات التكوين الرئيسية
    echo -e "${YELLOW}⚙️  ملفات التكوين:${NC}"
    find "$dir" -name "*.json" -o -name "*.yaml" -o -name "*.yml" 2>/dev/null | \
    grep -E "(config|setting)" | head -5 | while read file; do
        echo -e "  ${BLUE}⚙ ${NC}$file"
    done
    
    # قواعد البيانات
    echo -e "${YELLOW}🗃️  قواعد البيانات:${NC}"
    find "$dir" -name "*.db" -o -name "*.sqlite" 2>/dev/null | head -5 | while read file; do
        size=$(du -h "$file" 2>/dev/null | cut -f1)
        echo -e "  ${PURPLE}🗃 ${NC}$file (${GREEN}$size${NC})"
    done
    echo ""
}

# الواجهة الرئيسية
main_menu() {
    while true; do
        echo -e "${CYAN}=================================${NC}"
        echo -e "${GREEN}        عارض ملفات السيرفر${NC}"
        echo -e "${CYAN}=================================${NC}"
        echo -e "${YELLOW}1.${NC} 📊 إحصائيات سريعة"
        echo -e "${YELLOW}2.${NC} 📂 عرض الملفات حسب النوع"
        echo -e "${YELLOW}3.${NC} 🏆 أكبر المجلدات"
        echo -e "${YELLOW}4.${NC} 🕐 أحدث الملفات"
        echo -e "${YELLOW}5.${NC} 🌳 هيكل المجلدات"
        echo -e "${YELLOW}6.${NC} 🔍 ملفات مهمة"
        echo -e "${YELLOW}7.${NC} 🎯 Hyper Factory المدمج"
        echo -e "${YELLOW}8.${NC} 🚀 Hyper Factory النهائي"
        echo -e "${YELLOW}9.${NC} 📁 تغيير المسار"
        echo -e "${YELLOW}0.${NC} ❌ خروج"
        echo -e "${CYAN}=================================${NC}"
        
        read -p "اختر خيارًا [0-9]: " choice
        
        case $choice in
            1)
                show_quick_stats
                ;;
            2)
                show_files_by_type "$(pwd)"
                ;;
            3)
                show_largest_dirs "$(pwd)"
                ;;
            4)
                show_recent_files "$(pwd)"
                ;;
            5)
                read -p "أدعم العمق [2]: " depth
                depth=${depth:-2}
                show_directory_tree "$(pwd)" "$depth"
                ;;
            6)
                find_important_files "$(pwd)"
                ;;
            7)
                echo -e "${GREEN}📁 Hyper Factory المدمج:${NC}"
                show_files_by_type "/root/hyper-factory-merged"
                show_largest_dirs "/root/hyper-factory-merged"
                ;;
            8)
                echo -e "${GREEN}📁 Hyper Factory النهائي:${NC}"
                show_files_by_type "/root/hyper-factory"
                show_largest_dirs "/root/hyper-factory"
                ;;
            9)
                read -p "أدخل المسار الجديد: " new_path
                if [ -d "$new_path" ]; then
                    cd "$new_path"
                    echo -e "${GREEN}✅ تم الانتقال إلى: $(pwd)${NC}"
                else
                    echo -e "${RED}❌ المسار غير موجود: $new_path${NC}"
                fi
                ;;
            0)
                echo -e "${GREEN}👋 مع السلامة!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ خيار غير صحيح${NC}"
                ;;
        esac
        
        read -p "اضغط Enter للمتابعة..."
        clear
    done
}

# التشغيل التلقائي
clear
show_quick_stats
main_menu

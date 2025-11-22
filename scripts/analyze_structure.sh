#!/bin/bash

echo "🔍 فحص هيكل HyperFactory الشامل"
echo "================================"
echo "الوقت: $(date)"
echo ""

HYPER_ROOT="/root/HyperFFactory"

# الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

analyze_directory_structure() {
    echo -e "${BLUE}📁 الهيكل الأساسي:${NC}"
    echo "المسار الجذر: $HYPER_ROOT"
    echo ""
    
    # فحص المجلدات الرئيسية
    main_dirs=("scripts" "db" "stack" "src" "opt")
    for dir in "${main_dirs[@]}"; do
        if [ -d "$HYPER_ROOT/$dir" ]; then
            size=$(du -sh "$HYPER_ROOT/$dir" 2>/dev/null | cut -f1)
            count=$(find "$HYPER_ROOT/$dir" -type f 2>/dev/null | wc -l)
            echo -e "  ${GREEN}✅ $dir${NC} ($size, $count ملف)"
        else
            echo -e "  ${RED}❌ $dir${NC} (مفقود)"
        fi
    done
}

analyze_scripts_structure() {
    echo -e "\n${BLUE}⚙️  هيكل السكربتات:${NC}"
    
    script_categories=("core" "ai" "maintenance" "services" "integration" "suites")
    for category in "${script_categories[@]}"; do
        if [ -d "$HYPER_ROOT/scripts/$category" ]; then
            script_count=$(find "$HYPER_ROOT/scripts/$category" -name "*.sh" -type f 2>/dev/null | wc -l)
            echo -e "  ${GREEN}✅ $category${NC} ($script_count سكربت)"
            
            # عرض أهم السكربتات
            if [ "$script_count" -gt 0 ]; then
                find "$HYPER_ROOT/scripts/$category" -name "*.sh" -type f | head -3 | while read script; do
                    echo "    📜 $(basename "$script")"
                done
                if [ "$script_count" -gt 3 ]; then
                    echo "    ... و $(($script_count - 3)) أكثر"
                fi
            fi
        else
            echo -e "  ${RED}❌ $category${NC}"
        fi
    done
}

analyze_database_structure() {
    echo -e "\n${BLUE}💾 هيكل قواعد البيانات:${NC}"
    
    if [ -d "$HYPER_ROOT/db" ]; then
        db_dirs=("identity" "tasks" "skills" "knowledge")
        for db_dir in "${db_dirs[@]}"; do
            if [ -d "$HYPER_ROOT/db/$db_dir" ]; then
                db_files=$(find "$HYPER_ROOT/db/$db_dir" -name "*.db" -type f 2>/dev/null | wc -l)
                echo -e "  ${GREEN}✅ $db_dir${NC} ($db_files قاعدة بيانات)"
                
                # عرض قواعد البيانات
                find "$HYPER_ROOT/db/$db_dir" -name "*.db" -type f | while read db; do
                    size=$(du -h "$db" | cut -f1)
                    echo "    🗃️  $(basename "$db") ($size)"
                done
            else
                echo -e "  ${RED}❌ $db_dir${NC}"
            fi
        done
    else
        echo -e "  ${RED}❌ مجلد db غير موجود${NC}"
    fi
}

analyze_smartfriend_integration() {
    echo -e "\n${BLUE}🤖 تكامل SmartFriend:${NC}"
    
    # فحص وجود SmartFriend Suite
    if [ -d "/opt/smartfriend-suite" ]; then
        echo -e "  ${GREEN}✅ SmartFriend Suite${NC} (موجود في /opt/)"
        suite_size=$(du -sh "/opt/smartfriend-suite" 2>/dev/null | cut -f1 || echo "غير معروف")
        echo "    المسار: /opt/smartfriend-suite ($suite_size)"
    elif [ -d "$HYPER_ROOT/opt/smartfriend-suite" ]; then
        echo -e "  ${GREEN}✅ SmartFriend Suite${NC} (مدمج في HyperFactory)"
        suite_size=$(du -sh "$HYPER_ROOT/opt/smartfriend-suite" 2>/dev/null | cut -f1 || echo "غير معروف")
        echo "    المسار: $HYPER_ROOT/opt/smartfriend-suite ($suite_size)"
    else
        echo -e "  ${YELLOW}⚠️  SmartFriend Suite${NC} (غير موجود - يحتاج تكامل)"
    fi
    
    # فحص الخدمات
    echo -e "\n  ${BLUE}🚀 خدمات Systemd:${NC}"
    services=("sf-health" "sf-memory" "sf-unified" "sf-web" "sf-bot")
    for service in "${services[@]}"; do
        if systemctl is-active "${service}.service" >/dev/null 2>&1; then
            echo -e "    ${GREEN}✅ $service.service${NC} (نشط)"
        elif systemctl is-enabled "${service}.service" >/dev/null 2>&1; then
            echo -e "    ${YELLOW}⏸️  $service.service${NC} (معطل)"
        else
            echo -e "    ${RED}❌ $service.service${NC} (غير موجود)"
        fi
    done
}

analyze_python_environment() {
    echo -e "\n${BLUE}🐍 بيئة Python:${NC}"
    
    # فحص الوحدات الأساسية
    python3 -c "import fastapi, sqlalchemy, psutil, requests" 2>/dev/null && \
        echo -e "  ${GREEN}✅ الوحدات الأساسية${NC} (مثبتة)" || \
        echo -e "  ${RED}❌ الوحدات الأساسية${NC} (مفقودة)"
    
    # فحص الوحدات المخصصة
    custom_modules=("ops" "apps" "core")
    for module in "${custom_modules[@]}"; do
        if python3 -c "import $module" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $module${NC} (متاحة)"
        else
            # البحث عن المسار
            found_path=$(find "$HYPER_ROOT" -type d -name "$module" 2>/dev/null | head -1)
            if [ -n "$found_path" ]; then
                echo -e "  ${YELLOW}⚠️  $module${NC} (موجود في: $found_path)"
            else
                echo -e "  ${RED}❌ $module${NC} (مفقود)"
            fi
        fi
    done
}

analyze_docker_environment() {
    echo -e "\n${BLUE}🐳 بيئة Docker:${NC}"
    
    if command -v docker >/dev/null 2>&1; then
        container_count=$(docker ps -q | wc -l)
        echo -e "  ${GREEN}✅ Docker${NC} (مثبت, $container_count حاوية نشطة)"
        
        # عرض الحاويات النشطة
        if [ "$container_count" -gt 0 ]; then
            docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -6
        fi
    else
        echo -e "  ${RED}❌ Docker${NC} (غير مثبت)"
    fi
    
    # فحص stacks
    if [ -d "$HYPER_ROOT/stack" ]; then
        stack_count=$(find "$HYPER_ROOT/stack" -name "docker-compose*.yml" -type f 2>/dev/null | wc -l)
        echo -e "  ${GREEN}✅ Stacks${NC} ($stack_count ملف docker-compose)"
    fi
}

analyze_worker_system() {
    echo -e "\n${BLUE}👷 نظام العمال:${NC}"
    
    if [ -f "$HYPER_ROOT/db/identity/identity.db" ]; then
        worker_count=$(sqlite3 "$HYPER_ROOT/db/identity/identity.db" "SELECT COUNT(*) FROM entities WHERE type='worker';" 2>/dev/null || echo "0")
        echo -e "  العمال المسجلين: $worker_count"
        
        if [ "$worker_count" -gt 0 ]; then
            echo "  العمال النشطين:"
            sqlite3 "$HYPER_ROOT/db/identity/identity.db" "SELECT name, capabilities FROM entities WHERE type='worker' AND status='active';" 2>/dev/null | while IFS='|' read name caps; do
                echo "    👤 $name - $caps"
            done
        fi
    else
        echo -e "  ${RED}❌ قاعدة بيانات الهوية غير موجودة${NC}"
    fi
}

generate_recommendations() {
    echo -e "\n${BLUE}🎯 التوصيات:${NC}"
    
    # توصيات بناءً على الفحص
    if [ ! -d "/opt/smartfriend-suite" ] && [ ! -d "$HYPER_ROOT/opt/smartfriend-suite" ]; then
        echo "  🔸 إعداد SmartFriend Suite (مفقود)"
    fi
    
    worker_count=$(sqlite3 "$HYPER_ROOT/db/identity/identity.db" "SELECT COUNT(*) FROM entities WHERE type='worker';" 2>/dev/null || echo "0")
    if [ "$worker_count" -eq "0" ]; then
        echo "  🔸 تسجيل العمال الأساسيين"
    fi
    
    if ! python3 -c "import ops, apps" 2>/dev/null; then
        echo "  🔸 إصلاح وحدات Python المفقودة"
    fi
    
    active_services=$(systemctl list-units "sf-*" --state=running --no-legend | wc -l)
    if [ "$active_services" -lt 3 ]; then
        echo "  🔸 تفعيل المزيد من الخدمات"
    fi
}

# التنفيذ الرئيسي
echo "بدء فحص الهيكل..."
echo ""

analyze_directory_structure
analyze_scripts_structure
analyze_database_structure
analyze_smartfriend_integration
analyze_python_environment
analyze_docker_environment
analyze_worker_system
generate_recommendations

echo -e "\n${GREEN}✅ اكتمل فحص الهيكل${NC}"
echo "الوقت: $(date)"

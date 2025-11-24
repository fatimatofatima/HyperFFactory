#!/bin/bash

echo "🧠 HYPER FACTORY BRAIN CONTROLLER - المدير المركزي للنظام"
echo "=========================================================="

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# المسارات الأساسية
HYPER_ROOT="/root/HyperFFactory"
SUITE_DIR="$HYPER_ROOT/opt/smartfriend-suite"
SCRIPTS_DIR="$HYPER_ROOT/scripts"
DB_DIR="$HYPER_ROOT/db"

scan_hyper_structure() {
    echo -e "\n${BLUE}🔍 فحص هيكل HyperFactory...${NC}"
    
    # 1. فحص المكونات الأساسية
    echo -e "\n${YELLOW}📁 المكونات الأساسية:${NC}"
    components=("scripts" "db" "stack" "src" "opt/smartfriend-suite")
    for comp in "${components[@]}"; do
        if [ -d "$HYPER_ROOT/$comp" ]; then
            echo -e "  ✅ $comp"
        else
            echo -e "  ❌ $comp"
        fi
    done
    
    # 2. فحص أنظمة العمال
    echo -e "\n${YELLOW}👷 أنظمة العمال:${NC}"
    worker_systems=("db/tasks" "db/identity" "db/skills")
    for system in "${worker_systems[@]}"; do
        if [ -d "$HYPER_ROOT/$system" ]; then
            count=$(find "$HYPER_ROOT/$system" -name "*.db" | wc -l)
            echo -e "  ✅ $system (قواعد بيانات: $count)"
        else
            echo -e "  ❌ $system"
        fi
    done
    
    # 3. فحص السكربتات الأساسية
    echo -e "\n${YELLOW}⚙️  السكربتات الأساسية:${NC}"
    essential_scripts=(
        "core/ffactory_controller.sh"
        "core/sf_layer_manager.sh" 
        "core/sf_service_matrix_complete.sh"
        "ai/run_agent_smart.sh"
        "maintenance/sf_smart_repair_manager.sh"
    )
    
    for script in "${essential_scripts[@]}"; do
        if [ -f "$SCRIPTS_DIR/$script" ]; then
            echo -e "  ✅ $script"
        else
            echo -e "  ❌ $script"
        fi
    done
}

scan_smartfriend_systems() {
    echo -e "\n${BLUE}🔍 فحص أنظمة SmartFriend الفرعية...${NC}"
    
    # 1. فحص خدمات SmartFriend
    echo -e "\n${YELLOW}🚀 خدمات SmartFriend:${NC}"
    services=("sf-health.service" "sf-memory.service" "sf-unified.service" "sf-web.service")
    for service in "${services[@]}"; do
        if systemctl is-active "$service" >/dev/null 2>&1; then
            echo -e "  ✅ $service - نشط"
        elif systemctl is-enabled "$service" >/dev/null 2>&1; then
            echo -e "  ⏳ $service - معطل"
        else
            echo -e "  ❌ $service - غير موجود"
        fi
    done
    
    # 2. فحص قواعد البيانات
    echo -e "\n${YELLOW}💾 قواعد البيانات:${NC}"
    databases=(
        "$SUITE_DIR/memory.db"
        "$SUITE_DIR/smartfriend_unified.db" 
        "$DB_DIR/tasks/tasks.db"
        "$DB_DIR/identity/identity.db"
    )
    
    for db in "${databases[@]}"; do
        if [ -f "$db" ]; then
            size=$(du -h "$db" | cut -f1)
            echo -e "  ✅ $(basename $db) ($size)"
        else
            echo -e "  ❌ $(basename $db)"
        fi
    done
}

discover_missing_dependencies() {
    echo -e "\n${BLUE}🔎 اكتشاف الملفات المطلوبة...${NC}"
    
    # البحث عن الملفات الحرجة المفقودة
    echo -e "\n${YELLOW}📋 الملفات المطلوبة:${NC}"
    
    # 1. ملفات Python الأساسية
    python_files=("ops" "apps" "core")
    for pkg in "${python_files[@]}"; do
        if find "$HYPER_ROOT" -type d -name "$pkg" | grep -q .; then
            echo -e "  ✅ حزمة Python: $pkg"
        else
            echo -e "  ❌ حزمة Python: $pkg"
        fi
    done
    
    # 2. ملفات التكوين
    config_files=(
        "$SUITE_DIR/config/suite.conf"
        "$SUITE_DIR/.env"
        "$HYPER_ROOT/.hyperconfig"
    )
    
    for config in "${config_files[@]}"; do
        if [ -f "$config" ]; then
            echo -e "  ✅ تكوين: $(basename $config)"
        else
            echo -e "  ❌ تكوين: $(basename $config)"
        fi
    done
}

activate_hyper_brain() {
    echo -e "\n${BLUE}🚀 تفعيل العقل المدير HyperFactory...${NC}"
    
    # 1. بدء نظام الهوية أولاً
    echo -e "\n${YELLOW}🆔 تفعيل نظام الهوية...${NC}"
    if [ -f "$SCRIPTS_DIR/core/sf_identity_manager.sh" ]; then
        $SCRIPTS_DIR/core/sf_identity_manager.sh --register-workers
        echo -e "  ✅ نظام الهوية مفعل"
    else
        echo -e "  ❌ سكربت الهوية غير موجود"
    fi
    
    # 2. تشغيل المتحكم الرئيسي
    echo -e "\n${YELLOW}🎮 تشغيل المتحكم الرئيسي...${NC}"
    if [ -f "$SCRIPTS_DIR/core/ffactory_controller.sh" ]; then
        $SCRIPTS_DIR/core/ffactory_controller.sh status
        echo -e "  ✅ المتحكم الرئيسي نشط"
    else
        echo -e "  ❌ المتحكم الرئيسي غير موجود"
    fi
    
    # 3. تفعيل نظام المهام
    echo -e "\n${YELLOW}📋 تفعيل نظام المهام...${NC}"
    if [ -f "$SCRIPTS_DIR/core/sf_layer_manager.sh" ]; then
        $SCRIPTS_DIR/core/sf_layer_manager.sh --start-foundation
        echo -e "  ✅ نظام المهام مفعل"
    else
        echo -e "  ❌ نظام المهام غير موجود"
    fi
}

show_hyper_dashboard() {
    echo -e "\n${GREEN}📊 لوحة تحكم HyperFactory - المدير المركزي${NC}"
    echo "================================================"
    
    # حالة النظام
    echo -e "\n${YELLOW}🔄 الحالة الحالية:${NC}"
    
    # عدد العمال المسجلين
    if [ -f "$DB_DIR/identity/identity.db" ]; then
        worker_count=$(sqlite3 "$DB_DIR/identity/identity.db" "SELECT COUNT(*) FROM entities WHERE type='worker';" 2>/dev/null || echo "0")
        echo -e "  👷 العمال المسجلين: $worker_count"
    else
        echo -e "  👷 العمال المسجلين: ❌ قاعدة بيانات غير موجودة"
    fi
    
    # عدد المهام
    if [ -f "$DB_DIR/tasks/tasks.db" ]; then
        task_count=$(sqlite3 "$DB_DIR/tasks/tasks.db" "SELECT COUNT(*) FROM jobs;" 2>/dev/null || echo "0")
        echo -e "  📋 المهام النشطة: $task_count"
    else
        echo -e "  📋 المهام النشطة: ❌ قاعدة بيانات غير موجودة"
    fi
    
    # الخدمات النشطة
    active_services=$(systemctl list-units "sf-*" --state=running --no-legend | wc -l)
    echo -e "  🚀 الخدمات النشطة: $active_services"
    
    echo -e "\n${GREEN}✅ HyperFactory جاهز كعقل مدير مركزي${NC}"
}

# التنفيذ الرئيسي
case "${1:-scan}" in
    "scan")
        scan_hyper_structure
        scan_smartfriend_systems
        discover_missing_dependencies
        ;;
    "activate")
        scan_hyper_structure
        activate_hyper_brain
        show_hyper_dashboard
        ;;
    "dashboard")
        show_hyper_dashboard
        ;;
    *)
        echo "استخدام: $0 [scan|activate|dashboard]"
        echo "  scan - فحص الهيكل فقط"
        echo "  activate - تفعيل النظام"
        echo "  dashboard - عرض اللوحة فقط"
        ;;
esac

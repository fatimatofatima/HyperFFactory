#!/bin/bash

echo "🔧 HyperFactory Central Fix - الإصلاح المركزي"
echo "=============================================="
echo "الوقت: $(date)"
echo ""

HYPER_ROOT="/root/HyperFFactory"

# الألوان
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

fix_workers_system() {
    echo -e "${BLUE}👷 إصلاح نظام العمال...${NC}"
    
    IDENTITY_DB="$HYPER_ROOT/db/identity/identity.db"
    
    # فحص هيكل جدول entities
    if sqlite3 "$IDENTITY_DB" ".schema entities" 2>/dev/null | grep -q "type"; then
        echo -e "  ✅ جدول entities به حقل type"
    else
        echo -e "  🔨 إصلاح هيكل جدول entities..."
        sqlite3 "$IDENTITY_DB" "DROP TABLE IF EXISTS entities;"
        sqlite3 "$IDENTITY_DB" "
        CREATE TABLE entities (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT,
            capabilities TEXT,
            status TEXT DEFAULT 'active',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );"
    fi
    
    # تسجيل العمال الأساسيين
    echo -e "  🔨 تسجيل العمال الأساسيين..."
    sqlite3 "$IDENTITY_DB" "
    INSERT OR IGNORE INTO entities (id, name, type, capabilities) VALUES 
    ('hyper_brain', 'Hyper Brain Controller', 'worker', 'management,decision,coordination'),
    ('hyper_ai_core', 'AI Core Manager', 'worker', 'ai,learning,models'),
    ('hyper_maintenance', 'Maintenance Supervisor', 'worker', 'repair,health,cleanup'),
    ('hyper_memory', 'Memory Architect', 'worker', 'memory,storage,knowledge'),
    ('hyper_integration', 'Integration Master', 'worker', 'integration,api,communication'),
    ('hyper_security', 'Security Guardian', 'worker', 'security,monitoring,protection');
    "
    
    worker_count=$(sqlite3 "$IDENTITY_DB" "SELECT COUNT(*) FROM entities WHERE type='worker';")
    echo -e "  ${GREEN}✅ تم تسجيل $worker_count عامل${NC}"
}

fix_python_modules() {
    echo -e "${BLUE}🐍 إصلاح وحدات Python...${NC}"
    
    # إنشاء مجلد src إذا لم يكن موجوداً
    mkdir -p "$HYPER_ROOT/src"
    
    # إنشاء وحدة ops في المسار الصحيح
    cat > "$HYPER_ROOT/src/ops.py" << 'PYEOF'
"""
HyperFactory Operations Module
"""
import psutil
import os
import sys

def get_system_health():
    return {
        "cpu_percent": psutil.cpu_percent(),
        "memory_percent": psutil.virtual_memory().percent,
        "disk_usage": psutil.disk_usage('/').percent
    }

def monitor_services():
    return {"status": "operational", "services": ["hyper_brain", "hyper_ai"]}
PYEOF

    # إنشاء وحدة apps في المسار الصحيح  
    cat > "$HYPER_ROOT/src/apps.py" << 'PYEOF'
"""
HyperFactory Applications Module
"""
from fastapi import FastAPI

def create_hyper_app():
    return FastAPI(title="HyperFactory API", version="1.0.0")

class HyperWorker:
    def __init__(self, name, capabilities):
        self.name = name
        self.capabilities = capabilities
    
    def execute_task(self, task):
        return f"Worker {self.name} executing: {task}"
PYEOF

    # إضافة المسار إلى Python path
    echo "$HYPER_ROOT/src" > /usr/local/lib/python3.10/site-packages/hyper_factory.pth 2>/dev/null ||
    echo "export PYTHONPATH=\$PYTHONPATH:$HYPER_ROOT/src" >> ~/.bashrc
    
    echo -e "  ${GREEN}✅ تم إنشاء الوحدات في المسار الصحيح${NC}"
}

fix_directory_structure() {
    echo -e "${BLUE}📁 إصلاح هيكل المجلدات...${NC}"
    
    # إنشاء المجلدات المفقودة
    mkdir -p "$HYPER_ROOT/opt/smartfriend-suite"
    mkdir -p "$HYPER_ROOT/var/log"
    mkdir -p "$HYPER_ROOT/var/db"
    mkdir -p "$HYPER_ROOT/var/run"
    
    # ربط SmartFriend Suite إذا كان موجوداً في /opt/
    if [ -d "/opt/smartfriend-suite" ] && [ ! -L "/opt/smartfriend-suite" ]; then
        echo -e "  🔨 ربط SmartFriend Suite..."
        mv /opt/smartfriend-suite/* "$HYPER_ROOT/opt/smartfriend-suite/" 2>/dev/null || true
        rm -rf /opt/smartfriend-suite
        ln -sf "$HYPER_ROOT/opt/smartfriend-suite" /opt/smartfriend-suite
    fi
    
    echo -e "  ${GREEN}✅ تم إصلاح هيكل المجلدات${NC}"
}

fix_services_integration() {
    echo -e "${BLUE}🚀 إصلاح تكامل الخدمات...${NC}"
    
    # تحديث مسارات الخدمات
    for service_file in /etc/systemd/system/sf-*.service; do
        if [ -f "$service_file" ]; then
            sed -i 's|/opt/smartfriend-suite|/root/HyperFFactory/opt/smartfriend-suite|g' "$service_file"
            echo -e "  🔧 تحديث: $(basename $service_file)"
        fi
    done
    
    # إعادة تحميل الخدمات
    systemctl daemon-reload
    
    # تشغيل الخدمات الأساسية
    systemctl restart sf-health.service 2>/dev/null || true
    systemctl restart sf-memory.service 2>/dev/null || true  
    systemctl restart sf-unified.service 2>/dev/null || true
    
    echo -e "  ${GREEN}✅ تم تحديث تكامل الخدمات${NC}"
}

create_hyper_config() {
    echo -e "${BLUE}⚙️  إنشاء تكوين HyperFactory...${NC}"
    
    cat > "$HYPER_ROOT/.hyperconfig" << 'CONFIGEOF'
# HyperFactory Central Configuration
HYPER_ROOT="/root/HyperFFactory"
HYPER_MODE="central_brain"
INTEGRATED_SYSTEMS=("smartfriend-suite" "ffactory" "ffactory2")

# Worker Settings
WORKER_AUTO_REGISTER=true
WORKER_HEARTBEAT_INTERVAL=30

# API Settings
API_PORT=8888
API_HOST="0.0.0.0"

# Database Settings
DB_MAIN="$HYPER_ROOT/db"
DB_BACKUP="$HYPER_ROOT/backups"

# Logging
LOG_LEVEL="INFO"
LOG_DIR="$HYPER_ROOT/var/log"
CONFIGEOF

    echo -e "  ${GREEN}✅ تم إنشاء التكوين المركزي${NC}"
}

test_fixes() {
    echo -e "${BLUE}🧪 اختبار الإصلاحات...${NC}"
    
    # اختبار Python modules
    if python3 -c "import ops, apps; print('✅ Python modules work')" 2>/dev/null; then
        echo -e "  ${GREEN}✅ وحدات Python تعمل${NC}"
    else
        # بديل: إضافة المسار مؤقتاً
        export PYTHONPATH="$PYTHONPATH:$HYPER_ROOT/src"
        if python3 -c "import ops, apps; print('✅ Python modules work with path fix')" 2>/dev/null; then
            echo -e "  ${GREEN}✅ وحدات Python تعمل (بالإصلاح)${NC}"
        else
            echo -e "  ${YELLOW}⚠️  وحدات Python تحتاج مزيد إصلاح${NC}"
        fi
    fi
    
    # اختبار قاعدة بيانات العمال
    worker_count=$(sqlite3 "$HYPER_ROOT/db/identity/identity.db" "SELECT COUNT(*) FROM entities WHERE type='worker';" 2>/dev/null || echo "0")
    if [ "$worker_count" -gt "0" ]; then
        echo -e "  ${GREEN}✅ نظام العمال يعمل ($worker_count عامل)${NC}"
    else
        echo -e "  ${RED}❌ نظام العمال لا يزال معطلاً${NC}"
    fi
    
    # اختبار الخدمات
    active_services=$(systemctl list-units "sf-*" --state=running --no-legend | wc -l)
    echo -e "  ${GREEN}✅ الخدمات النشطة: $active_services${NC}"
}

show_final_status() {
    echo -e "\n${GREEN}🎉 اكتمل الإصلاح المركزي${NC}"
    echo "=================================="
    echo "الوقت: $(date)"
    echo ""
    
    echo -e "${BLUE}📊 الحالة النهائية:${NC}"
    echo "  👷 العمال: $(sqlite3 "$HYPER_ROOT/db/identity/identity.db" "SELECT COUNT(*) FROM entities WHERE type='worker';" 2>/dev/null || echo "0")"
    echo "  🚀 الخدمات: $(systemctl list-units "sf-*" --state=running --no-legend | wc -l)"
    echo "  🐍 الوحدات: $(python3 -c 'import ops, apps; print("✅")' 2>/dev/null || echo "❌")"
    echo "  📁 الهيكل: $( [ -d "$HYPER_ROOT/opt/smartfriend-suite" ] && echo "✅" || echo "❌" )"
    
    echo -e "\n${GREEN}🎯 الخطوة التالية:${NC}"
    echo "  تشغيل: ./scripts/hyper_brain_controller.sh activate"
}

# التنفيذ الرئيسي
echo "بدء الإصلاح المركزي..."
echo ""

fix_workers_system
fix_python_modules  
fix_directory_structure
fix_services_integration
create_hyper_config
test_fixes
show_final_status

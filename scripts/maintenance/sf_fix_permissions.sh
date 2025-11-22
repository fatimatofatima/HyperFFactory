#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

# ألوان للتنسيق
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log(){ echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn(){ echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
error(){ echo -e "${RED}[$(date '+%F %T')] [ERROR]${NC} $*" >&2; }
success(){ echo -e "${GREEN}[$(date '+%F %T')] [SUCCESS]${NC} $*"; }

log "=== إصلاح صلاحيات مجلدات SmartFriend Suite ==="
echo

# 1) الصلاحيات الأساسية للمسارات الرئيسية
log "1️⃣ ضبط الصلاحيات الأساسية..."

PATHS=(
    "/opt"
    "/opt/smartfriend-suite"
    "/opt/smartfriend-suite/smartfriend"
    "/opt/smartfriend-suite/smartfriend/app"
    "/opt/smartfriend-suite/gateway"
    "/opt/smartfriend-suite/data"
    "/opt/smartfriend-suite/integrations"
    "/opt/smartfriend-suite/scripts"
)

for path in "${PATHS[@]}"; do
    if [ -d "$path" ]; then
        if chmod 755 "$path" 2>/dev/null; then
            success "   ✅ $path - صلاحيات 755"
        else
            error "   ❌ $path - فشل ضبط الصلاحيات"
        fi
    else
        warn "   ⚠️ $path - غير موجود"
    fi
done

# 2) صلاحيات venv والمكتبات
log "2️⃣ ضبط صلاحيات الـ Virtual Environment..."

VENV_PATHS=(
    "/opt/smartfriend-suite/smartfriend/venv"
    "/opt/smartfriend-suite/smartfriend/venv/bin"
    "/opt/smartfriend-suite/smartfriend/venv/lib"
    "/opt/smartfriend-suite/smartfriend/venv/lib/python3.10"
    "/opt/smartfriend-suite/smartfriend/venv/lib/python3.10/site-packages"
)

for path in "${VENV_PATHS[@]}"; do
    if [ -d "$path" ]; then
        chmod 755 "$path" 2>/dev/null && success "   ✅ $path - صلاحيات 755" || warn "   ⚠️ $path - مشكلة في الصلاحيات"
    fi
done

# 3) صلاحيات ملفات Python القابلة للتنفيذ
log "3️⃣ ضبط صلاحيات ملفات Python التنفيذية..."

PYTHON_FILES=(
    "/opt/smartfriend-suite/smartfriend/venv/bin/python"
    "/opt/smartfriend-suite/smartfriend/venv/bin/python3"
    "/opt/smartfriend-suite/smartfriend/venv/bin/pip"
    "/opt/smartfriend-suite/smartfriend/venv/bin/uvicorn"
)

for file in "${PYTHON_FILES[@]}"; do
    if [ -f "$file" ]; then
        chmod 755 "$file" 2>/dev/null && success "   ✅ $file - صلاحيات 755" || warn "   ⚠️ $file - مشكلة في الصلاحيات"
    fi
done

# 4) صلاحيات قاعدة البيانات
log "4️⃣ ضبط صلاحيات قاعدة البيانات..."

DB_PATHS=(
    "/opt/smartfriend-suite/data"
    "/opt/smartfriend-suite/data/smartfriend_unified.db"
)

for path in "${DB_PATHS[@]}"; do
    if [ -e "$path" ]; then
        if [ -f "$path" ]; then
            chmod 644 "$path" 2>/dev/null && success "   ✅ $path - صلاحيات 644" || warn "   ⚠️ $path - مشكلة في الصلاحيات"
        else
            chmod 755 "$path" 2>/dev/null && success "   ✅ $path - صلاحيات 755" || warn "   ⚠️ $path - مشكلة في الصلاحيات"
        fi
    else
        warn "   ⚠️ $path - غير موجود"
    fi
done

# 5) صلاحيات السكربتات
log "5️⃣ ضبط صلاحيات السكربتات..."

SCRIPTS_DIR="/opt/smartfriend-suite/scripts"
if [ -d "$SCRIPTS_DIR" ]; then
    find "$SCRIPTS_DIR" -name "*.py" -o -name "*.sh" | while read script; do
        if [ -f "$script" ]; then
            chmod 755 "$script" 2>/dev/null && echo "   ✅ $script - صلاحيات 755" || echo "   ⚠️ $script - مشكلة في الصلاحيات"
        fi
    done
    success "   ✅ تم ضبط صلاحيات سكربتات $SCRIPTS_DIR"
else
    warn "   ⚠️ $SCRIPTS_DIR - غير موجود"
fi

# 6) صلاحيات الـ logs
log "6️⃣ ضبط صلاحيات مجلدات اللوجات..."

LOG_PATHS=(
    "/opt/smartfriend-suite/smartfriend/logs"
    "/var/log/smartfriend"
    "/var/log/smartfrind"
)

for path in "${LOG_PATHS[@]}"; do
    if [ -d "$path" ]; then
        chmod 755 "$path" 2>/dev/null && success "   ✅ $path - صلاحيات 755" || warn "   ⚠️ $path - مشكلة في الصلاحيات"
        # إنشاء ملف log افتراضي إذا لم يكن موجوداً
        touch "$path/smartfriend.log" 2>/dev/null && chmod 644 "$path/smartfriend.log" 2>/dev/null || true
    else
        # إنشاء المجلد إذا لم يكن موجوداً
        mkdir -p "$path" 2>/dev/null && chmod 755 "$path" 2>/dev/null && success "   ✅ تم إنشاء $path - صلاحيات 755" || warn "   ⚠️ فشل إنشاء $path"
    fi
done

# 7) إصلاح ملكية الملفات (اختياري - بحذر)
log "7️⃣ ضبط ملكية الملفات (اختياري)..."

# اكتشاف المستخدم الذي تشتغل به الخدمات
APP_USER=$(systemctl show -p User --value smartfrind-api.service 2>/dev/null || echo "root")
log "   👤 مستخدم الخدمات: $APP_USER"

if [ "$APP_USER" != "root" ]; then
    # ضبط الملكية للمستخدم المحدد
    chown -R "$APP_USER:$APP_USER" /opt/smartfriend-suite/data 2>/dev/null && success "   ✅ تم ضبط ملكية /opt/smartfriend-suite/data لـ $APP_USER" || warn "   ⚠️ مشكلة في ضبط ملكية data"
    chown -R "$APP_USER:$APP_USER" /var/log/smartfriend 2>/dev/null && success "   ✅ تم ضبط ملكية /var/log/smartfriend لـ $APP_USER" || warn "   ⚠️ مشكلة في ضبط ملكية logs"
else
    warn "   ⚠️ الخدمات تعمل كـ root - لا داعي لتغيير الملكية"
fi

# 8) التحقق النهائي من الصلاحيات
log "8️⃣ التحقق النهائي من الصلاحيات..."

echo
log "📁 صلاحيات المسارات الرئيسية:"
ls -ld /opt /opt/smartfriend-suite /opt/smartfriend-suite/smartfriend /opt/smartfriend-suite/data 2>/dev/null | while read line; do
    echo "   $line"
done

echo
log "🐍 صلاحيات Python التنفيذي:"
ls -l /opt/smartfriend-suite/smartfriend/venv/bin/python 2>/dev/null && success "   ✅ Python جاهز للتنفيذ" || error "   ❌ مشكلة في Python"

echo
log "🗄️ صلاحيات قاعدة البيانات:"
ls -l /opt/smartfriend-suite/data/smartfriend_unified.db 2>/dev/null && success "   ✅ قاعدة البيانات متاحة للقراءة" || warn "   ⚠️ قاعدة البيانات غير موجودة أو غير قابلة للوصول"

# 9) اختبار تشغيل الخدمات
log "9️⃣ اختبار تشغيل الخدمات بعد إصلاح الصلاحيات..."

TEST_SERVICES=(
    "smartfrind-api.service"
    "sf-core.service"
    "smartfrind-runner.service"
)

for service in "${TEST_SERVICES[@]}"; do
    if systemctl is-active "$service" >/dev/null 2>&1; then
        success "   ✅ $service - نشط"
    else
        warn "   ⚠️ $service - غير نشط، جاري التشغيل..."
        systemctl start "$service" 2>/dev/null && success "   ✅ تم تشغيل $service" || error "   ❌ فشل تشغيل $service"
    fi
done

echo
success "=== تم الانتهاء من إصلاح الصلاحيات ==="
log "💡 تم ضبط جميع الصلاحيات الأساسية لـ SmartFriend Suite"
log "📋 الملخص:"
echo "   • ✅ المسارات الرئيسية: 755"
echo "   • ✅ ملفات Python: 755" 
echo "   • ✅ قاعدة البيانات: 644"
echo "   • ✅ مجلدات اللوجات: 755"
echo "   • ✅ السكربتات: 755"


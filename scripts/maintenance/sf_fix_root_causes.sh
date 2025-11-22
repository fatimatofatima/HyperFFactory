#!/bin/bash
set -euo pipefail

echo "=== إصلاح الأسباب الجذرية للمشاكل ==="
echo ""

# 1. إصلاح مشاكل الصلاحيات
echo "🔐 إصلاح صلاحيات الملفات والمجلدات..."
chmod +x /opt/smartfriend-suite/bin/sf-service-* 2>/dev/null || true
chmod +x /opt/smartfriend-suite/scripts/*.sh 2>/dev/null || true

# 2. إصلاح مشاكل Python modules المفقودة
echo "🐍 فحص وإصلاح مشاكل Python modules..."
find /opt/smartfriend-suite -name "*.py" -type f | head -10 | while read -r pyfile; do
    echo "   📁 فحص: $(basename "$pyfile")"
done

# 3. إصلاح الخدمات التي تعاني من مشاكل في المسارات
echo "📁 إنشاء المجلدات المفقودة..."
mkdir -p /opt/smartfriend-suite/smartfriend/logs
mkdir -p /opt/smartfriend-suite/apps/smartfriend-api
mkdir -p /opt/smartfriend-suite/apps/web
mkdir -p /opt/smartfriend-suite/apps/unified
mkdir -p /var/lib/smartfrind
mkdir -p /var/log/smartfrind

# 4. إصلاح صلاحيات virtual environment
echo "🔧 إصلاح virtual environment..."
if [ -d "/opt/smartfriend-suite/smartfriend/venv" ]; then
    chmod -R 755 /opt/smartfriend-suite/smartfriend/venv/bin/ 2>/dev/null || true
    # إصلاح صلاحيات ملف python التنفيذي
    find /opt/smartfriend-suite/smartfriend/venv/bin -name "python*" -type f | while read -r pybin; do
        chmod +x "$pybin" 2>/dev/null || true
    done
fi

# 5. إصلاح ملفات الخدمات المعطوبة
echo "⚙️ إصلاح تعريفات الخدمات..."

# إصلاح smartfriend-api.service - المسار غير موجود
if systemctl cat smartfriend-api.service >/dev/null 2>&1; then
    CURRENT_WD=$(systemctl show -p WorkingDirectory --value smartfriend-api.service)
    if [ ! -d "$CURRENT_WD" ]; then
        echo "   🔧 إصلاح WorkingDirectory لـ smartfriend-api.service"
        sudo sed -i 's|WorkingDirectory=.*|WorkingDirectory=/opt/smartfriend-suite|' /etc/systemd/system/smartfriend-api.service
    fi
fi

# 6. إيقاف الخدمات التي تستهلك موارد بدون فائدة
echo "🛑 إيقاف الخدمات التي تعيد التشغيل باستمرار..."
SERVICES_TO_STOP="smartfrind-ai-gateway.service smartfrind-advanced.service smartfrind-local.service sf-web.service sf-unified.service"

for service in $SERVICES_TO_STOP; do
    if systemctl is-active "$service" >/dev/null 2>&1 || systemctl is-failed "$service" >/dev/null 2>&1; then
        echo "   ⏹️ إيقاف $service"
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        # منع إعادة التشغيل التلقائي
        systemctl mask "$service" 2>/dev/null || true
    fi
done

# 7. إصلاح الخدمات الأساسية فقط
echo "🚀 تشغيل الخدمات الأساسية فقط..."
CORE_SERVICES="sf-core.service smartfrind-api.service smartfrind-ask.service smartfrind-simple.service smartfrind-ultra.service"

for service in $CORE_SERVICES; do
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "   🔄 إعادة تشغيل $service"
        systemctl restart "$service" 2>/dev/null || true
    fi
done

# 8. تنظيف السجلات القديمة
echo "🧹 تنظيف السجلات..."
journalctl --vacuum-time=1h 2>/dev/null || true

echo ""
echo "✅ تم الانتهاء من الإصلاحات الأساسية"
echo ""
echo "📊 الحالة الحالية:"
systemctl list-units "sf-*" "smartfrind-*" --state=active --no-pager --no-legend | head -10

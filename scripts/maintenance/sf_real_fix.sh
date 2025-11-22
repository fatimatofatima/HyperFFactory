#!/bin/bash

echo "============================================================"
echo "            الإصلاح الفعلي للمشاكل الأساسية"
echo "============================================================"

# 1. إصلاح مشاكل Python Modules
echo "🔧 1. إصلاح مشاكل الـ Python Modules..."
cd /opt/smartfriend-suite

# فحص مجلدات apps
echo "📁 فحص مجلدات apps:"
ls -la apps/

# إنشاء الملفات الناقصة إذا لزم
if [ ! -d "apps/unified" ]; then
    echo "📦 إنشاء apps/unified..."
    mkdir -p apps/unified
    cat > apps/unified/__init__.py <<'PYINIT'
# Unified API module
__version__ = "1.0.0"
PYINIT
fi

if [ ! -d "apps/memory" ]; then
    echo "📦 إنشاء apps/memory..."
    mkdir -p apps/memory  
    cat > apps/memory/__init__.py <<'PYINIT'
# Memory API module
__version__ = "1.0.0"
PYINIT
fi

# 2. إصلاح مشاكل systemd Environment
echo "🔧 2. إصلاح مشاكل الـ Environment..."

# فحص ملف البيئة
if [ -f "/etc/smartfriend/sf_suite.env" ]; then
    echo "📄 فحص ملف البيئة:"
    head -20 /etc/smartfriend/sf_suite.env
    
    # إصلاح التنسيق إذا لزم
    if grep -q "export " /etc/smartfriend/sf_suite.env; then
        echo "🔄 إصلاح تنسيق ملف البيئة..."
        cp /etc/smartfriend/sf_suite.env /etc/smartfriend/sf_suite.env.backup
        sed 's/export //g' /etc/smartfriend/sf_suite.env.backup > /etc/smartfriend/sf_suite.env
        echo "✅ تم إصلاح تنسيق ملف البيئة"
    fi
fi

# 3. إصلاح Nginx
echo "🔧 3. إصلاح Nginx..."

# تنظيف الملفات المكررة
echo "🧹 تنظيف ملفات Nginx المكررة..."
ls -la /etc/nginx/sites-enabled/

# إزالة النسخ الاحتياطية القديمة
find /etc/nginx/sites-enabled/ -name "*.backup.*" -delete

# إعادة تحميل systemd
echo "🔄 إعادة تحميل systemd..."
systemctl daemon-reload

# 4. تشغيل الخدمات الأساسية فقط
echo "🚀 4. تشغيل الخدمات الأساسية..."

# فقط الخدمات التي نعرف أنها تعمل
for service in sf-core.service sf-bot.service; do
    if systemctl is-active --quiet "$service"; then
        echo "✅ $service - نشط"
    else
        echo "🔧 تشغيل $service..."
        systemctl start "$service"
    fi
done

# 5. تقرير الحالة النهائية
echo "📊 الحالة النهائية:"
echo "🔌 البورتات النشطة:"
ss -tulpn | grep -E '(:80|:8211)' | head -10

echo "🛠️ الخدمات النشطة:"
systemctl list-units "sf-*" --no-legend | grep "running" | head -10

echo "============================================================"
echo "            تم الإصلاح الأساسي - جاهز للخطوة التالية"
echo "============================================================"

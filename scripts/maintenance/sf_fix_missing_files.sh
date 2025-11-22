#!/bin/bash

echo "=================================================="
echo "   إصلاح ملفات SmartFriend المفقودة - الإصدار الطارئ"
echo "=================================================="

# إيقاف الخدمات المكسورة أولاً
echo "⏹️  إيقاف الخدمات المكسورة..."
systemctl stop sf-bot-programmer.service 2>/dev/null || true
systemctl stop sf-spider.service 2>/dev/null || true
systemctl stop sf-bot-behavior.service 2>/dev/null || true
systemctl stop sf-bot-assistant.service 2>/dev/null || true

# تعطيل الـ auto-restart مؤقتاً
echo "🚫 تعطيل الـ auto-restart..."
systemctl disable sf-bot-programmer.service 2>/dev/null || true
systemctl disable sf-spider.service 2>/dev/null || true

# فحص الملفات المفقودة
echo "🔍 فحص الملفات المفقودة..."
MISSING_FILES=()

# فحص ملفات البوتات
if [[ ! -f "/opt/smartfriend-suite/smartfriend/app/apps/telegram-bots/main.py" ]]; then
    MISSING_FILES+=("telegram-bots/main.py")
    echo "❌ ملف البوتات الرئيسي مفقود"
fi

# فحص ملفات السبايدر
if [[ ! -f "/opt/smartfriend-suite/ops/spider_config_complete.yaml" ]]; then
    MISSING_FILES+=("spider_config_complete.yaml")
    echo "❌ ملف إعدادات السبايدر مفقود"
fi

# البحث عن بدائل للملفات المفقودة
echo "🔎 البحث عن بدائل للملفات المفقودة..."

# البحث عن أي ملفات بوتات
find /opt/smartfriend-suite -name "*.py" -path "*/telegram*" -o -name "*.py" -path "*/bot*" | head -5

# البحث عن أي ملفات إعدادات
find /opt/smartfriend-suite -name "*.yaml" -o -name "*.yml" | head -5

# إنشاء هيكل مجلدات أساسي إذا محتاج
echo "📁 إنشاء هيكل مجلدات أساسي..."
mkdir -p /opt/smartfriend-suite/smartfriend/app/apps/telegram-bots
mkdir -p /opt/smartfriend-suite/ops

# اقتراح حلول
echo ""
echo "🎯 الحلول المقترحة:"
echo "1. البوتات تحتاج ملفات من: /opt/smartfriend-suite/smartfriend/app/apps/telegram-bots/"
echo "2. السبايدر يحتاج ملف: /opt/smartfriend-suite/ops/spider_config_complete.yaml"
echo ""
echo "📝 الخطوات:"
echo "1. افحص الـ GitHub repos عشان الملفات المفقودة"
echo "2. أنشئ ملفات بديلة مؤقتة للتجربة"
echo "3. صحح مسارات systemd services"

# اقتراح إنشاء ملفات بديلة مؤقتة
echo ""
read -p "هل تريد إنشاء ملفات بديلة مؤقتة للتجربة؟ (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📝 إنشاء ملف بوت بديل مؤقت..."
    cat > /opt/smartfriend-suite/smartfriend/app/apps/telegram-bots/main.py <<'PYTHON'
#!/usr/bin/env python3
print("SmartFriend Bot - Temporary placeholder")
print("Bot is working - Files need to be restored from GitHub")
while True:
    import time
    time.sleep(10)
PYTHON

    echo "📝 إنشاء ملف إعدادات سبايدر مؤقت..."
    cat > /opt/smartfriend-suite/ops/spider_config_complete.yaml <<'YAML'
# Temporary spider configuration
spider:
  enabled: true
  debug: true
  intervals:
    harvest: 300
    ingest: 60
YAML

    echo "✅ تم إنشاء الملفات البديلة المؤقتة"
fi

# إعادة تشغيل الخدمات بعد الإصلاح
echo ""
echo "🔄 إعادة تشغيل الخدمات بعد الإصلاح..."
systemctl daemon-reload

# تشغيل الخدمات الأساسية فقط للتأكد
echo "🚀 تشغيل الخدمات الأساسية..."
systemctl start sf-core.service
systemctl start sf-memory.service
systemctl start smartfrind-api.service

echo ""
echo "✅ تم الإصلاح الطارئ"
echo "📋 الخطوات القادمة:"
echo "1. راجع الـ GitHub repos علشان الملفات الأصلية"
echo "2. استبدل الملفات المؤقتة بالملفات الحقيقية"
echo "3. فعل الخدمات بعد التأكد من وجود الملفات"

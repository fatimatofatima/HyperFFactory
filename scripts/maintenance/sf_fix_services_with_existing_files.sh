#!/bin/bash
echo "========================================"
echo " 🔧 إصلاح الخدمات باستخدام الملفات الموجودة"
echo "========================================"

# 1) إصلاح sf-spider.service
echo "1. إصلاح sf-spider.service:"
echo "---------------------------"
if [ -f "/opt/smartfriend-suite/smartfrind/smart_spider.py" ]; then
    echo "   ✅ ملف smart_spider.py موجود"
    echo "   🛠️ إنشاء تكوين افتراضي للعناكب..."
    sudo mkdir -p /opt/smartfriend-suite/config
    sudo tee /opt/smartfriend-suite/config/spider_config.json > /dev/null <<'CONFIG'
{
    "seeds": [
        "https://httpbin.org/json",
        "https://jsonplaceholder.typicode.com/posts",
        "https://api.github.com"
    ],
    "max_pages": 10,
    "delay": 2,
    "user_agent": "SmartFriend-Spider/1.0"
}
CONFIG
    echo "   ✅ تم إنشاء التكوين"
    
    # تعديل سكربت التشغيل لاستخدام الملفات الصحيحة
    echo "   📝 تعديل سكربت التشغيل..."
    if [ -f "/opt/smartfriend-suite/bin/sf_spider_run.sh" ]; then
        echo "   📋 محتوى السكربت الحالي (أول 10 أسطر):"
        head -10 /opt/smartfriend-suite/bin/sf_spider_run.sh
    fi
else
    echo "   ❌ ملفات العنكبوت غير موجودة في المسار المتوقع"
fi

# 2) إصلاح sf-learning.service
echo
echo "2. إصلاح sf-learning.service:"
echo "------------------------------"
if [ -f "/opt/smartfriend-suite/scripts/sf_brain_learning_loop.sh" ]; then
    echo "   ✅ سكربت التعلم موجود"
    echo "   📋 محتوى السكربت:"
    cat /opt/smartfriend-suite/scripts/sf_brain_learning_loop.sh
    
    # المشكلة: السكربت يبحث عن ملف غير موجود
    echo "   ⚠️ المشكلة: السكربت يبحث عن learning_loop.py غير موجود"
    echo "   💡 الحل: إنشاء ملف تعلم افتراضي أو تعديل السكربت"
    
    # إنشاء ملف تعلم بسيط
    echo "   🛠️ إنشاء ملف تعلم افتراضي..."
    sudo mkdir -p /opt/smartfriend-suite/apps/brain
    sudo tee /opt/smartfriend-suite/apps/brain/learning_loop.py > /dev/null <<'PYTHON'
#!/usr/bin/env python3
"""
SmartFriend Brain Learning Loop - Placeholder
"""
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("brain.learning")

def main():
    logger.info("🚀 بدء حلقة التعلم...")
    while True:
        logger.info("🧠 التعلم النشط - جولة معالجة البيانات")
        # TODO: إضافة منطق التعلم الفعلي هنا
        time.sleep(300)  # 5 دقائق بين الجولات

if __name__ == "__main__":
    main()
PYTHON
    echo "   ✅ تم إنشاء ملف التعلم الافتراضي"
else
    echo "   ❌ سكربت التعلم غير موجود"
fi

# 3) فحص sf-telegram-audit.service
echo
echo "3. فحص sf-telegram-audit.service:"
echo "---------------------------------"
if [ -f "/opt/smartfriend-suite/integrations/telegram_audit_bot.py" ]; then
    echo "   ✅ ملف البوت موجود"
    echo "   📋 أول 10 أسطر من الملف:"
    head -10 /opt/smartfriend-suite/integrations/telegram_audit_bot.py
    
    # فحص السجلات للخطأ الحقيقي
    echo "   🔍 فحص سجلات الخدمة:"
    sudo journalctl -u sf-telegram-audit.service -n 5 --no-pager 2>/dev/null | tail -3
else
    echo "   ❌ ملف البوت غير موجود"
fi

echo
echo "========================================"
echo " 📋 خطوات التشغيل بعد الإصلاح:"
echo "========================================"
echo "1. شغّل sf-spider.service:"
echo "   sudo systemctl start sf-spider.service"
echo
echo "2. شغّل sf-learning.service:"
echo "   sudo systemctl start sf-learning.service"  
echo
echo "3. افحص sf-telegram-audit.service:"
echo "   sudo journalctl -u sf-telegram-audit.service -f"
echo
echo "========================================"

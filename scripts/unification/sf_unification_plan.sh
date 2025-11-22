#!/bin/bash
echo "🎯 خطة توحيد SmartFriend Suite - الإصدار التنفيذي"
echo "=================================================="
echo

echo "المرحلة 1: تأسيس النواة الموحدة (اليوم 1)"
echo "----------------------------------------"
echo "✅ 1.1 تفعيل الخدمات الأساسية من sf-*:"
echo "   - sf-unified.service (البوابة الرئيسية)"
echo "   - sf-memory.service (الذاكرة - إصلاحها أولاً)"
echo "   - sf-web.service (الواجهة - إصلاحها أولاً)"
echo "   - sf-health.service (المراقبة - إصلاحها أولاً)"
echo
echo "✅ 1.2 نقل أقوى منطق من smartfrind-* إلى sf-*:"
echo "   - أخذ منطق الحصاد من smartfrind-harvest لتعزيز sf-spider"
echo "   - أخذ منطق التعلم من smartfrind-learning لتعزيز sf-learning"
echo "   - أخذ منطق الحراسة من smartfrind-guardian لتعزيز sf-health"
echo

echo "المرحلة 2: توحيد البوتات (اليوم 2)"
echo "--------------------------------"
echo "🤖 2.1 إنشاء كتالوج البوتات الرسمي:"
echo "   - البوت الرئيسي: sf-bot.service"
echo "   - بوت المبرمج: sf-bot-programmer.service" 
echo "   - بوت المراجعة: sf-telegram-audit.service"
echo "   - إيقاف جميع البوتات المكررة"
echo
echo "🔧 2.2 توحيد إدارة التوكنات:"
echo "   - ملف إعدادات موحد: /etc/smartfriend/sf_suite.env"
echo "   - إزالة الاعتماد على إعدادات smartfrind-*"
echo

echo "المرحلة 3: توحيد واجهات البرمجة (اليوم 3)"
echo "----------------------------------------"
echo "🌐 3.1 إصلاح وتفعيل جميع واجهات sf-*:"
echo "   - البوابة الرئيسية (port 8210)"
echo "   - واجهة الذاكرة (port 8214)" 
echo "   - واجهة الويب (port 8390)"
echo "   - واجهة الموحدة (port 8220)"
echo
echo "🔄 3.2 تحديث Nginx للتوجيه لـ sf-* فقط:"
echo "   - /api/ → sf-unified.service"
echo "   - /memory/ → sf-memory.service"
echo "   - /web/ → sf-web.service"
echo   - إزالة جميع التوجيهات لـ smartfrind-*"
echo

echo "المرحلة 4: التجميد والتنظيف (اليوم 4)"
echo "------------------------------------"
echo "🧹 4.1 تجميد خدمات smartfrind-*:"
echo "   - systemctl stop smartfrind-*"
echo "   - systemctl disable smartfrind-*"
echo "   - أرشفة وحدات systemd القديمة"
echo
echo "📊 4.2 التحقق النهائي:"
echo "   - جميع البورتات تشتغل من sf-* فقط"
echo "   - جميع البوتات تستخدم التوكنات الجديدة"
echo   - لا توجد أخطاء في السجلات"
echo

echo "المرحلة 5: التوثيق والتسليم (اليوم 5)"
echo "------------------------------------"
echo "📚 5.1 توثيق الهندسة الجديدة:"
echo "   - خريطة الخدمات النهائية"
echo "   - دليل الإدارة والصيانة"
echo "   - خطة الاسترجاع عند الطلب"
echo
echo "🎉 5.2 التسليم:"
echo "   - SmartFriend Suite موحدة بالكامل"
echo "   - أداء محسن وموثوقية أعلى"
echo "   - صيانة أسهل وتطوير أسرع"

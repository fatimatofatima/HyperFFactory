#!/bin/bash

# سكربت متقدم لفحص وتحليل شجرة مجلدات ffactory
# إعداد: 2025-11-11

echo "🌳 فحص شجرة مجلدات ffactory - النظام الجنائي المتكامل"
echo "======================================================"

# المسار الأساسي
FFACTORY_PATH="/opt/ffactory"

# التحقق من وجود المسار
if [[ ! -d "$FFACTORY_PATH" ]]; then
    echo "❌ مجلد ffactory غير موجود في: $FFACTORY_PATH"
    echo "🔍 جاري البحث عن المسار الصحيح..."
    find / -name "ffactory" -type d 2>/dev/null | head -5
    exit 1
fi

echo "✅ تم العثور على ffactory في: $FFACTORY_PATH"
echo "📊 الحجم الإجمالي: $(du -sh "$FFACTORY_PATH" | cut -f1)"

# إنشاء تقرير مفصل
REPORT_FILE="/tmp/ffactory_analysis_$(date +%Y%m%d_%H%M%S).txt"
{
echo "# تحليل شاملة لنظام ffactory"
echo "## تاريخ التقرير: $(date)"
echo ""

echo "## 📁 الهيكل التنظيمي الرئيسي"
echo "========================================"

echo "### 🏗️  المجلدات الرئيسية:"
find "$FFACTORY_PATH" -maxdepth 1 -type d | sort | while read dir; do
    dir_name=$(basename "$dir")
    dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
    file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo "- $dir_name ($dir_size, $file_count ملف)"
done

echo ""
echo "### 🔍 التطبيقات والخدمات (apps):"
echo "إجمالي التطبيقات: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d | wc -l)"
echo ""

# تحليل التطبيقات حسب النوع
echo "#### 📊 تصنيف التطبيقات:"
echo "- 🔍 **تحليل الوسائط**: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*media*" -o -name "*video*" -o -name "*audio*" | wc -l) تطبيق"
echo "- 🤖 **الذكاء الاصطناعي**: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*ai*" -o -name "*nlp*" -o -name "*neural*" | wc -l) تطبيق"  
echo "- 🕵️ **التحليل الجنائي**: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*forensic*" -o -name "*analyzer*" -o -name "*detector*" | wc -l) تطبيق"
echo "- 🌐 **التكامل والشبكات**: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*social*" -o -name "*network*" -o -name "*api*" | wc -l) تطبيق"
echo "- 📈 **التقارير واللوحات**: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*dashboard*" -o -name "*report*" -o -name "*analytics*" | wc -l) تطبيق"

echo ""
echo "### 💾 البيانات والتخزين:"
echo "- **قواعد البيانات**: $(find "$FFACTORY_PATH/data" -name "*.db" -o -name "*.sqlite" 2>/dev/null | wc -l)"
echo "- **النسخ الاحتياطية**: $(find "$FFACTORY_PATH/backup*" -type f 2>/dev/null | wc -l) ملف"
echo "- **السجلات**: $(find "$FFACTORY_PATH/logs" -type f 2>/dev/null | wc -l) ملف"

echo ""
echo "## 📊 الإحصائيات التفصيلية"
echo "========================================"

echo "### 📄 أنواع الملفات:"
echo "- 🐍 **بايثون**: $(find "$FFACTORY_PATH" -name "*.py" | wc -l) ملف"
echo "- 🛠️ **سكربتات**: $(find "$FFACTORY_PATH" -name "*.sh" | wc -l) ملف"
echo "- ⚙️ **إعدادات**: $(find "$FFACTORY_PATH" -name "*.json" -o -name "*.yaml" -o -name "*.yml" | wc -l) ملف"
echo "- 🐳 **دوكر**: $(find "$FFACTORY_PATH" -name "Dockerfile" | wc -l) ملف"
echo "- 📝 **نصوص**: $(find "$FFACTORY_PATH" -name "*.txt" -o -name "*.md" | wc -l) ملف"
echo "- 💾 **قواعد بيانات**: $(find "$FFACTORY_PATH" -name "*.db" -o -name "*.sqlite" | wc -l) ملف"

echo ""
echo "### 📈 الإحصائيات العامة:"
echo "- 📂 **المجلدات الإجمالية**: $(find "$FFACTORY_PATH" -type d | wc -l)"
echo "- 📄 **الملفات الإجمالية**: $(find "$FFACTORY_PATH" -type f | wc -l)"
echo "- 💿 **الحجم الإجمالي**: $(du -sh "$FFACTORY_PATH" | cut -f1)"

echo ""
echo "## 🎯 التطبيقات الرئيسية المميزة"
echo "========================================"

# تطبيقات الذكاء الاصطناعي
echo "### 🤖 تطبيقات الذكاء الاصطناعي:"
find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*ai*" -o -name "*neural*" -o -name "*nlp*" | while read app; do
    app_name=$(basename "$app")
    app_files=$(find "$app" -name "*.py" -o -name "*.sh" 2>/dev/null | wc -l)
    echo "- $app_name ($app_files ملف برمجي)"
done

# تطبيقات التحليل الجنائي
echo ""
echo "### 🕵️ تطبيقات التحليل الجنائي:"
find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*forensic*" -o -name "*analyzer*" -o -name "*detector*" | while read app; do
    app_name=$(basename "$app")
    app_size=$(du -sh "$app" 2>/dev/null | cut -f1)
    echo "- $app_name ($app_size)"
done

# تطبيقات الوسائط
echo ""
echo "### 📷 تطبيقات تحليل الوسائط:"
find "$FFACTORY_PATH/apps" -maxdepth 1 -type d -name "*media*" -o -name "*video*" -o -name "*audio*" -o -name "*vision*" | while read app; do
    app_name=$(basename "$app")
    has_docker=$(find "$app" -name "Dockerfile" 2>/dev/null | wc -l)
    has_requirements=$(find "$app" -name "requirements.txt" 2>/dev/null | wc -l)
    echo "- $app_name $(if [ $has_docker -gt 0 ]; then echo "🐳"; fi) $(if [ $has_requirements -gt 0 ]; then echo "📦"; fi)"
done

echo ""
echo "## 🔧 حالة النظام"
echo "========================================"

# التحقق من خدمات الدوكر
echo "### 🐳 حالة حاويات الدوكر:"
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -i ffactory || echo "لا توجد حاويات ffactory نشطة"
else
    echo "الدوكر غير مثبت"
fi

echo ""
echo "### 📋 السكربتات المتاحة:"
echo "- **سكربتات التشغيل**: $(find "$FFACTORY_PATH/scripts" -name "*.sh" | wc -l) سكربت"
echo "- **سكربتات الصيانة**: $(find "$FFACTORY_PATH/scripts" -name "*fix*" -o -name "*repair*" | wc -l) سكربت"
echo "- **سكربتات المراقبة**: $(find "$FFACTORY_PATH/scripts" -name "*health*" -o -name "*monitor*" | wc -l) سكربت"

echo ""
echo "## 💡 توصيات التشغيل"
echo "========================================"

echo "### 🚀 للتشغيل السريع:"
echo "1. تشغيل الخدمات الأساسية:"
echo "   cd $FFACTORY_PATH && docker-compose -f stack/docker-compose.core.yml up -d"
echo ""
echo "2. تشغيل التطبيقات:"
echo "   cd $FFACTORY_PATH && docker-compose -f stack/docker-compose.apps.yml up -d"
echo ""
echo "3. مراقبة النظام:"
echo "   $FFACTORY_PATH/scripts/ff_healthd.py"

echo ""
echo "### 🔍 للفحص المتقدم:"
echo "1. فحص الصحة: $FFACTORY_PATH/ff_doctor.sh"
echo "2. النسخ الاحتياطي: $FFACTORY_PATH/scripts/ff_backup.sh"
echo "3. المراقبة: $FFACTORY_PATH/scripts/ff_live_monitor.sh"

echo ""
echo "---"
echo "*تم إنشاء التقرير بواسطة ffactory_tree_analyzer.sh*"
echo "*نظام ffactory الجنائي المتكامل*"
} > "$REPORT_FILE"

echo "✅ تم إنشاء التقرير في: $REPORT_FILE"

# عرض ملخص سريع
echo ""
echo "🎯 الملخص السريع:"
echo "=================="
echo "📁 المجلدات الرئيسية: $(find "$FFACTORY_PATH" -maxdepth 1 -type d | wc -l)"
echo "🤖 التطبيقات: $(find "$FFACTORY_PATH/apps" -maxdepth 1 -type d | wc -l)"
echo "🐍 ملفات بايثون: $(find "$FFACTORY_PATH" -name "*.py" | wc -l)"
echo "🛠️ سكربتات: $(find "$FFACTORY_PATH" -name "*.sh" | wc -l)"
echo "🐳 ملفات دوكر: $(find "$FFACTORY_PATH" -name "Dockerfile" | wc -l)"
echo "📊 الحجم الإجمالي: $(du -sh "$FFACTORY_PATH" | cut -f1)"

# إذا كان tree مثبتاً، نعرض شجرة مختصرة
if command -v tree &> /dev/null; then
    echo ""
    echo "🌲 عرض شجرة مختصرة (مستويين):"
    tree "$FFACTORY_PATH" -L 2 -d | head -30
fi

echo ""
echo "📋 للمزيد من التفاصيل: cat $REPORT_FILE"

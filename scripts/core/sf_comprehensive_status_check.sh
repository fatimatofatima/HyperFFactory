#!/usr/bin/env bash
set -Eeuo pipefail

echo "================================================"
echo "   🔍 الفحص الشامل - النظام المتكامل النهائي"
echo "================================================"
echo ""

DB_PATH="/var/lib/smartfrind/smart_memory.db"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "📅 وقت الفحص: $TIMESTAMP"
echo ""

# 1) حالة قواعد البيانات
echo "1. 📊 حالة قواعد البيانات:"
echo "----------------------------------------"
sqlite3 "$DB_PATH" "
SELECT '🤖 ai_memory: ' || COUNT(*) || ' سجل' FROM ai_memory;
SELECT '🔍 ai_memory_fts: ' || COUNT(*) || ' سجل' FROM ai_memory_fts;
SELECT '📚 knowledge_base: ' || COUNT(*) || ' سجل' FROM knowledge_base;
SELECT '👤 user_memory: ' || COUNT(*) || ' سجل' FROM user_memory;
SELECT '🔄 interactions: ' || COUNT(*) || ' سجل' FROM interactions;
"

echo ""

# 2) هيكل الجداول الرئيسية
echo "2. 🏗️ هيكل الجداول الرئيسية:"
echo "----------------------------------------"
echo "📋 ai_memory:"
sqlite3 "$DB_PATH" "PRAGMA table_info(ai_memory);" | while read line; do
    IFS='|' read -ra cols <<< "$line"
    echo "   ${cols[1]} (${cols[2]})"
done

echo ""
echo "📋 knowledge_base:"
sqlite3 "$DB_PATH" "PRAGMA table_info(knowledge_base);" | while read line; do
    IFS='|' read -ra cols <<< "$line"
    echo "   ${cols[1]} (${cols[2]})"
done

echo ""

# 3) التصنيفات والتمثيل
echo "3. 🏷️ توزيع التصنيفات (أعلى 15):"
echo "----------------------------------------"
sqlite3 "$DB_PATH" "
SELECT 
    category, 
    COUNT(*) as count,
    printf('%.1f%%', (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM knowledge_base))) as percentage
FROM knowledge_base 
GROUP BY category 
ORDER BY count DESC
LIMIT 15;
" | while IFS='|' read category count percentage; do
    printf "   %-25s %-4s سجل %-6s\n" "$category" "$count" "$percentage"
done

echo ""

# 4) فحص FTS والبحث
echo "4. 🔍 فحص نظام البحث (FTS):"
echo "----------------------------------------"
echo "🎯 اختبار بحث 'python':"
sqlite3 "$DB_PATH" "
SELECT COUNT(*) FROM ai_memory_fts WHERE ai_memory_fts MATCH 'python';
" | while read count; do
    echo "   النتائج: $count سجل"
done

echo "🎯 اختبار بحث 'docker':"
sqlite3 "$DB_PATH" "
SELECT COUNT(*) FROM ai_memory_fts WHERE ai_memory_fts MATCH 'docker';
" | while read count; do
    echo "   النتائج: $count سجل"
done

echo "🎯 اختبار بحث 'machine learning':"
sqlite3 "$DB_PATH" "
SELECT COUNT(*) FROM ai_memory_fts WHERE ai_memory_fts MATCH 'machine learning';
" | while read count; do
    echo "   النتائج: $count سجل"
done

echo ""

# 5) Triggers والاستدامة
echo "5. ⚙️ فحص الـ Triggers والاستدامة:"
echo "----------------------------------------"
sqlite3 "$DB_PATH" "
SELECT name, type FROM sqlite_master 
WHERE type IN ('trigger', 'index') 
AND (name LIKE '%ai_memory%' OR name LIKE '%fts%')
ORDER BY type, name;
" | while IFS='|' read name type; do
    echo "   $type: $name"
done

echo ""

# 6) الخدمات النشطة
echo "6. 🚀 الخدمات النشطة:"
echo "----------------------------------------"
echo "🔧 بوابات المعرفة:"
ps aux | grep -E "(sf_update_unified_gateway|sf_update_learning_gateway)" | grep -v grep | while read line; do
    pid=$(echo $line | awk '{print $2}')
    cmd=$(echo $line | awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=""; print $0}')
    echo "   📍 PID $pid: $cmd"
done

echo ""
echo "🌐 الخدمات الأخرى:"
ps aux | grep -E "(uvicorn|python.*app)" | grep -v grep | grep -v "sf_update_" | while read line; do
    pid=$(echo $line | awk '{print $2}')
    cmd=$(echo $line | awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=""; print $0}' | cut -c1-60)
    echo "   📍 PID $pid: $cmd"
done

echo ""

# 7) فحص البوابات عبر HTTP
echo "7. 🌐 فحص البوابات عبر HTTP:"
echo "----------------------------------------"
echo "🔄 فحص Unified Gateway (8221):"
if curl -s http://localhost:8221/api/knowledge/stats > /dev/null; then
    echo "   ✅ البوابة نشطة - http://localhost:8221/docs"
else
    echo "   ❌ البوابة غير متاحة"
fi

echo "🔄 فحص Learning Gateway (8222):"
if curl -s http://localhost:8222/api/learn/random > /dev/null; then
    echo "   ✅ البوابة نشطة - http://localhost:8222/docs"
else
    echo "   ❌ البوابة غير متاحة"
fi

echo ""

# 8) جودة البيانات
echo "8. 📈 جودة البيانات:"
echo "----------------------------------------"
sqlite3 "$DB_PATH" "
SELECT 
    'أسئلة غير فارغة: ' || COUNT(*) 
FROM knowledge_base 
WHERE question IS NOT NULL AND question != '';

SELECT 
    'إجابات غير فارغة: ' || COUNT(*) 
FROM knowledge_base 
WHERE answer IS NOT NULL AND answer != '';

SELECT 
    'سجلات بدون تصنيف: ' || COUNT(*) 
FROM knowledge_base 
WHERE category IS NULL OR category = '';

SELECT 
    'أحدث سجل: ' || MAX(created_at) 
FROM knowledge_base;
"

echo ""

# 9) فحص الـ Spider
echo "9. 🕷️ حالة الـ Spider:"
echo "----------------------------------------"
if [ -f "/opt/smartfriend-suite/bots/smart_spider.py" ]; then
    echo "✅ ملف الـ Spider موجود"
    
    # فحص إذا كان فيه إدخال مباشر في FTS
    if grep -q "INSERT INTO ai_memory_fts" /opt/smartfriend-suite/bots/smart_spider.py; then
        echo "❌ يوجد إدخال مباشر في ai_memory_fts - يحتاج إصلاح"
    else
        echo "✅ لا يوجد إدخال مباشر في ai_memory_fts"
    fi
    
    # فحص التوافق مع الهيكل الحالي
    if grep -q "user_input.*ai_memory_fts" /opt/smartfriend-suite/bots/smart_spider.py; then
        echo "❌ يوجد مشاكل توافق مع ai_memory_fts"
    else
        echo "✅ الهيكل متوافق مع ai_memory_fts"
    fi
else
    echo "❌ ملف الـ Spider غير موجود"
fi

echo ""

# 10) الملخص النهائي
echo "10. 📋 الملخص النهائي:"
echo "----------------------------------------"
TOTAL_KB=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM knowledge_base;")
TOTAL_CATEGORIES=$(sqlite3 "$DB_PATH" "SELECT COUNT(DISTINCT category) FROM knowledge_base;")
FTS_WORKS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ai_memory_fts WHERE ai_memory_fts MATCH 'python';")
GATEWAYS_WORKING=0

if curl -s http://localhost:8221/api/knowledge/stats > /dev/null; then
    ((GATEWAYS_WORKING++))
fi
if curl -s http://localhost:8222/api/learn/random > /dev/null; then
    ((GATEWAYS_WORKING++))
fi

echo "   📚 إجمالي المعرفة: $TOTAL_KB سجل"
echo "   🏷️ عدد التصنيفات: $TOTAL_CATEGORIES فئة"
echo "   🔍 البحث النصي: $(if [ $FTS_WORKS -gt 0 ]; then echo "✅ يعمل"; else echo "❌ معطل"; fi)"
echo "   🌐 البوابات النشطة: $GATEWAYS_WORKING/2"
echo "   🕷️ حالة الـ Spider: $(if [ -f "/opt/smartfriend-suite/bots/smart_spider.py" ]; then echo "✅ موجود"; else echo "❌ مفقود"; fi)"

echo ""
echo "================================================"
echo "   ✅ الفحص الشامل اكتمل - $TIMESTAMP"
echo "================================================"

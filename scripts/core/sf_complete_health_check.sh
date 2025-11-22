#!/usr/bin/env bash
set -Eeuo pipefail

echo "================================================"
echo "  🩺 الفحص الصحي الشامل لنظام المعرفة"
echo "================================================"
echo

# دالة مساعدة
print_separator() {
    echo "----------------------------------------"
}

print_section() {
    echo
    echo "🧩 $1"
    print_separator
}

print_result() {
    local status=$1
    local message=$2
    if [ "$status" = "success" ]; then
        echo "   ✅ $message"
    elif [ "$status" = "warning" ]; then
        echo "   ⚠️  $message"
    else
        echo "   ❌ $message"
    fi
}

# الطابع الزمني
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "⏰ وقت الفحص: $TIMESTAMP"

########################################
# 1. فحص قاعدة البيانات
########################################
print_section "1. 📊 فحص قاعدة البيانات"

DB_PATH="/var/lib/smartfrind/smart_memory.db"

# فحص وجود الملف
if [ -f "$DB_PATH" ]; then
    print_result "success" "ملف قاعدة البيانات موجود"
    
    # فحص الجداول والسجلات
    DB_STATS=$(sqlite3 "$DB_PATH" "
        SELECT 
            (SELECT COUNT(*) FROM ai_memory) as ai_memory,
            (SELECT COUNT(*) FROM ai_memory_fts) as ai_memory_fts,
            (SELECT COUNT(*) FROM knowledge_base) as knowledge_base,
            (SELECT COUNT(DISTINCT category) FROM knowledge_base) as categories_count;
    ")
    
    IFS='|' read -r AI_MEMORY FTS_ENTRIES KNOWLEDGE_BASE CATEGORIES_COUNT <<< "$DB_STATS"
    
    print_result "success" "ai_memory: $AI_MEMORY سجل"
    print_result "success" "ai_memory_fts: $FTS_ENTRIES سجل" 
    print_result "success" "knowledge_base: $KNOWLEDGE_BASE سجل"
    print_result "success" "التصنيفات: $CATEGORIES_COUNT تصنيف"
    
    # فحص التزامن
    if [ "$AI_MEMORY" -eq "$FTS_ENTRIES" ] && [ "$FTS_ENTRIES" -eq "$KNOWLEDGE_BASE" ]; then
        print_result "success" "التزامن: جميع الجداول متزامنة"
    else
        print_result "warning" "التزامن: هناك اختلاف في عدد السجلات بين الجداول"
    fi
else
    print_result "error" "ملف قاعدة البيانات غير موجود: $DB_PATH"
fi

# فحص FTS
FTS_WORKS=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(*) FROM knowledge_base kb
    JOIN ai_memory_fts fts ON fts.rowid = kb.ai_id
    WHERE fts MATCH 'python'
    LIMIT 1;
" 2>/dev/null || echo "0")

if [ "$FTS_WORKS" -gt "0" ]; then
    print_result "success" "FTS: يعمل بشكل صحيح ($FTS_WORKS نتيجة لـ 'python')"
else
    print_result "warning" "FTS: قد يكون هناك مشكلة (لا توجد نتائج لـ 'python')"
fi

########################################
# 2. فحص البوابات والشبكات
########################################
print_section "2. 🌐 فحص البوابات والشبكات"

PORTS=("8221" "8222" "8223")
SERVICES=("البوابة البحثية" "بوابة التعلم" "البوابة المحسنة")

for i in "${!PORTS[@]}"; do
    PORT=${PORTS[$i]}
    SERVICE=${SERVICES[$i]}
    
    # فحص الـ LISTEN
    if ss -tln | grep -q ":$PORT "; then
        print_result "success" "$SERVICE ($PORT): البورت شغال"
        
        # فحص الـ health endpoint
        HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/health" 2>/dev/null || echo "000")
        
        if [ "$HEALTH_RESPONSE" = "200" ]; then
            # الحصول على تفاصيل الـ health
            HEALTH_DETAILS=$(curl -s "http://localhost:$PORT/health" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    status = data.get('status', 'unknown')
    service = data.get('service', 'unknown')
    knowledge = data.get('knowledge_system', 'N/A')
    print(f'{status} | {service} | معرفة: {knowledge}')
except:
    print('unknown | unknown | N/A')
" 2>/dev/null || echo "unknown | unknown | N/A")
            
            print_result "success" "$SERVICE: Health Check ناجح ($HEALTH_DETAILS)"
        else
            print_result "warning" "$SERVICE: Health Check فشل (كود: $HEALTH_RESPONSE)"
        fi
    else
        print_result "error" "$SERVICE ($PORT): البورت غير شغال"
    fi
done

########################################
# 3. فحص عمليات النظام
########################################
print_section "3. 🔍 فحص عمليات النظام"

# فحص عمليات Python المرتبطة
PYTHON_PROCESSES=$(ps aux | grep -E "8221|8222|8223" | grep python | grep -v grep | wc -l)

if [ "$PYTHON_PROCESSES" -ge 3 ]; then
    print_result "success" "عمليات Python: $PYTHON_PROCESSES عملية شغالة"
    
    # عرض التفاصيل
    echo "   📋 تفاصيل العمليات:"
    ps aux | grep -E "8221|8222|8223" | grep python | grep -v grep | while read line; do
        PID=$(echo "$line" | awk '{print $2}')
        CMD=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=$10=""; print $0}' | sed 's/^ *//')
        echo "      • PID $PID: $CMD"
    done
else
    print_result "warning" "عمليات Python: $PYTHON_PROCESSES عملية (مطلوب 3)"
fi

########################################
# 4. فحص نظام المعرفة
########################################
print_section "4. 🧠 فحص نظام المعرفة"

# فحص KnowledgeClient
cd /opt/smartfriend-suite
KNOWLEDGE_CLIENT_TEST=$(python3 -c "
import sys, asyncio
sys.path.insert(0, '/opt/smartfriend-suite')

try:
    from sf_knowledge_client_complete import KnowledgeClient
    print('SUCCESS: الاستيراد')
    
    async def test_client():
        try:
            client = KnowledgeClient()
            # اختبار البحث
            results = await client.search('python', limit=2)
            print(f'SUCCESS: البحث - {len(results)} نتيجة')
            
            # اختبار التعلم
            learning = await client.get_random_learning()
            status = learning.get('status', 'unknown')
            print(f'SUCCESS: التعلم - حالة: {status}')
            
        except Exception as e:
            print(f'ERROR: {e}')
    
    asyncio.run(test_client())
    
except ImportError as e:
    print(f'ERROR: الاستيراد - {e}')
except Exception as e:
    print(f'ERROR: عام - {e}')
" 2>&1)

# تحليل نتيجة الاختبار
if echo "$KNOWLEDGE_CLIENT_TEST" | grep -q "SUCCESS:"; then
    print_result "success" "KnowledgeClient: يعمل بشكل صحيح"
    echo "$KNOWLEDGE_CLIENT_TEST" | grep "SUCCESS:" | while read line; do
        echo "      📊 $(echo $line | cut -d':' -f2-)"
    done
else
    print_result "error" "KnowledgeClient: فشل في الاختبار"
    echo "$KNOWLEDGE_CLIENT_TEST" | grep "ERROR:" | while read line; do
        echo "      💥 $(echo $line | cut -d':' -f2-)"
    done
fi

########################################
# 5. فحص التكامل العملي
########################################
print_section "5. 🔄 فحص التكامل العملي"

# اختبار البحث من البوابة المحسنة
SEARCH_TEST=$(curl -s "http://localhost:8223/api/v2/search?query=python&limit=2" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    count = data.get('count', 0)
    source = data.get('source', 'unknown')
    status = data.get('status', 'unknown')
    
    if status == 'success' and count > 0:
        print(f'SUCCESS: {count} نتيجة من {source}')
        items = data.get('items', [])
        for i, item in enumerate(items[:2]):
            cat = item.get('category', 'N/A')
            quest = item.get('question', '')[:40]
            print(f'ITEM_{i+1}: {cat} - {quest}...')
    else:
        print(f'ERROR: حالة: {status}, نتائج: {count}')
        
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)

if echo "$SEARCH_TEST" | grep -q "SUCCESS"; then
    print_result "success" "البحث العملي: ناجح"
    echo "$SEARCH_TEST" | grep -E "SUCCESS|ITEM" | while read line; do
        echo "      🔍 $(echo $line | cut -d':' -f2-)"
    done
else
    print_result "error" "البحث العملي: فشل"
    echo "      💥 $SEARCH_TEST"
fi

# اختبار التعلم من البوابة المحسنة
LEARNING_TEST=$(curl -s "http://localhost:8223/api/v2/learn/random" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    status = data.get('status', 'unknown')
    source = data.get('source', 'unknown')
    
    if status == 'success':
        if data.get('data') and data['data'].get('item'):
            item = data['data']['item']
            category = item.get('category', 'N/A')
            print(f'SUCCESS: {category} من {source}')
        else:
            print('SUCCESS: عنصر تعليمي (بدون تفاصيل)')
    else:
        print(f'ERROR: حالة: {status}')
        
except Exception as e:
    print(f'ERROR: {e}')
" 2>&1)

if echo "$LEARNING_TEST" | grep -q "SUCCESS"; then
    print_result "success" "التعلم العملي: ناجح"
    echo "      🎓 $(echo "$LEARNING_TEST" | grep "SUCCESS" | cut -d':' -f2-)"
else
    print_result "error" "التعلم العملي: فشل"
    echo "      💥 $LEARNING_TEST"
fi

########################################
# 6. التقرير النهائي
########################################
print_section "6. 📈 التقرير النهائي"

# عد النتائج
SUCCESS_COUNT=$(grep -c "✅" <<< "$(cat /proc/self/fd/3)" 3<<< "$(cat /proc/self/fd/4)" 4<<< "$(cat /proc/self/fd/5)")
WARNING_COUNT=$(grep -c "⚠️" <<< "$(cat /proc/self/fd/3)" 3<<< "$(cat /proc/self/fd/4)" 4<<< "$(cat /proc/self/fd/5)")  
ERROR_COUNT=$(grep -c "❌" <<< "$(cat /proc/self/fd/3)" 3<<< "$(cat /proc/self/fd/4)" 4<<< "$(cat /proc/self/fd/5)")

echo "   📊 إحصائيات الفحص:"
echo "      • ✅ النجاح: $SUCCESS_COUNT"
echo "      • ⚠️  التحذيرات: $WARNING_COUNT" 
echo "      • ❌ الأخطاء: $ERROR_COUNT"

# التوصية النهائية
if [ "$ERROR_COUNT" -eq 0 ] && [ "$WARNING_COUNT" -eq 0 ]; then
    echo
    echo "🎉 **الحالة: ممتازة!** النظام يعمل بشكل كامل وجاهز للإنتاج."
    echo "   يمكن المضي قدماً في التكامل مع SmartFrind-Core."
elif [ "$ERROR_COUNT" -eq 0 ]; then
    echo  
    echo "⚠️  **الحالة: جيدة مع ملاحظات.** النظام يعمل ولكن هناك بعض التحذيرات."
    echo "   يوصى بمراجعة التحذيرات قبل التكامل الكامل."
else
    echo
    echo "❌ **الحالة: تحتاج إصلاح.** هناك أخطاء تحتاج المعالجة."
    echo "   يرجى معالجة الأخطاء قبل المتابعة للتكامل."
fi

echo
echo "================================================"
echo "  🩺 انتهى الفحص الصحي الشامل"
echo "================================================"

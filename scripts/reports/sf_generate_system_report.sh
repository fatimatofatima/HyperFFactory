#!/usr/bin/env bash
set -Eeuo pipefail

REPORT_FILE="/root/system_status_report_$(date +%Y%m%d_%H%M%S).txt"

{
echo "تقرير حالة النظام - SmartFriend Knowledge Base"
echo "=============================================="
echo "تاريخ التقرير: $(date)"
echo ""

echo "الإحصائيات العامة:"
echo "------------------"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT 'إجمالي السجلات: ' || COUNT(*) FROM knowledge_base;
SELECT 'عدد التصنيفات: ' || COUNT(DISTINCT category) FROM knowledge_base;
SELECT 'أقدم سجل: ' || MIN(created_at) FROM knowledge_base;
SELECT 'أحدث سجل: ' || MAX(created_at) FROM knowledge_base;
"

echo ""
echo "التوزيع التفصيلي للتصنيفات:"
echo "---------------------------"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT category, COUNT(*) as count,
       printf('%.1f%%', (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM knowledge_base))) as percentage
FROM knowledge_base 
GROUP BY category 
ORDER BY count DESC;
"

echo ""
echo "حالة الخدمات:"
echo "-------------"
echo "Unified Gateway: $(curl -s http://localhost:8221/api/knowledge/stats > /dev/null && echo 'نشط' || echo 'غير نشط')"
echo "Learning Gateway: $(curl -s http://localhost:8222/api/learn/random > /dev/null && echo 'نشط' || echo 'غير نشط')"

echo ""
echo "فحص الجودة:"
echo "-----------"
sqlite3 "/var/lib/smartfrind/smart_memory.db" "
SELECT 'أسئلة فارغة: ' || COUNT(*) FROM knowledge_base WHERE question IS NULL OR question = '';
SELECT 'إجابات فارغة: ' || COUNT(*) FROM knowledge_base WHERE answer IS NULL OR answer = '';
SELECT 'سجلات بدون مصدر: ' || COUNT(*) FROM knowledge_base WHERE source IS NULL OR source = '';
"

} > "$REPORT_FILE"

echo "✅ تم إنشاء التقرير في: $REPORT_FILE"
cat "$REPORT_FILE"

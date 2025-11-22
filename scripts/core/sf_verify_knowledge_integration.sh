#!/usr/bin/env bash
set -Eeuo pipefail

DB="/var/lib/smartfrind/smart_memory.db"

echo "🔍 التحقق النهائي من تكامل نظام المعرفة..."

echo ""
echo "1) 📊 إحصائيات قاعدة البيانات:"
sqlite3 "$DB" "
SELECT 
  (SELECT COUNT(*) FROM ai_memory)        AS ai_memory,
  (SELECT COUNT(*) FROM ai_memory_fts)   AS ai_memory_fts,
  (SELECT COUNT(*) FROM knowledge_base)  AS knowledge_base;
"

echo ""
echo "2) 🌐 بوابة البحث 8221:"
HTTP_CODE_SEARCH=$(curl -s -o /tmp/sf_kb_search.json -w "%{http_code}" "http://localhost:8221/api/knowledge/search?query=python&limit=1" || echo "000")
echo "   • كود HTTP: $HTTP_CODE_SEARCH"
if [ "$HTTP_CODE_SEARCH" = "200" ]; then
  python3 - << 'PY'
import json
from pathlib import Path

p = Path("/tmp/sf_kb_search.json")
try:
    data = json.loads(p.read_text(encoding="utf-8") or "{}")
except Exception as e:
    print(f"   • JSON error: {e}")
else:
    items = data.get("items") or []
    print(f"   • عدد النتائج: {len(items)}")
    if items:
        first = items[0]
        print(f"   • التصنيف الأول: {first.get('category', 'N/A')}")
        q = (first.get('question') or '')[:80]
        print(f"   • السؤال الأول: {q}")
PY
else
  echo "   • بوابة البحث غير متاحة أو تعيد خطأ (ليست 200)."
fi

echo ""
echo "3) 🎓 بوابة التعلم 8222:"
HTTP_CODE_LEARN=$(curl -s -o /tmp/sf_kb_learn.json -w "%{http_code}" "http://localhost:8222/api/learn/random" || echo "000")
echo "   • كود HTTP: $HTTP_CODE_LEARN"
if [ "$HTTP_CODE_LEARN" = "200" ]; then
  python3 - << 'PY'
import json
from pathlib import Path

p = Path("/tmp/sf_kb_learn.json")
try:
    data = json.loads(p.read_text(encoding="utf-8") or "{}")
except Exception as e:
    print(f"   • JSON error: {e}")
else:
    status = data.get("status", "N/A")
    item = data.get("item") or {}
    print(f"   • الحالة: {status}")
    if item:
        print(f"   • التصنيف: {item.get('category', 'N/A')}")
        q = (item.get('question') or '')[:80]
        print(f"   • السؤال: {q}")
PY
else
  echo "   • بوابة التعلم غير متاحة أو تعيد خطأ (ليست 200)."
fi

echo ""
echo "✅ انتهاء فحص تكامل نظام المعرفة."

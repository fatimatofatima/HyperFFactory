#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "   🗄️ Checking Suite Databases After Activation"
echo "==========================================="
echo

# فحص قواعد البيانات الرئيسية
DB_PATHS=(
    "/var/lib/smartfrind/smart_memory.db"
    "/opt/smartfriend-suite/data/memory.sqlite"
    "/opt/smartfrind/data/smartfrind.db"
)

for db in "${DB_PATHS[@]}"; do
    if [[ -f "$db" ]]; then
        echo "📊 $(basename "$db"):"
        echo "   📏 الحجم: $(du -h "$db" | cut -f1)"
        
        # فحص الجداول الرئيسية
        if sqlite3 "$db" ".tables" 2>/dev/null | grep -q "knowledge_base"; then
            count=$(sqlite3 "$db" "SELECT COUNT(*) FROM knowledge_base" 2>/dev/null || echo "0")
            echo "   📚 knowledge_base: $count سجل"
        fi
        
        if sqlite3 "$db" ".tables" 2>/dev/null | grep -q "ai_memory"; then
            count=$(sqlite3 "$db" "SELECT COUNT(*) FROM ai_memory" 2>/dev/null || echo "0")
            echo "   🤖 ai_memory: $count سجل"
        fi
    else
        echo "❌ $(basename "$db"): غير موجود"
    fi
    echo
done

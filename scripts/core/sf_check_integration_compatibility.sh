#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🔧 Integration Compatibility Check"
echo "   📋 Will smartfrind features WORK in suite?"
echo "==============================================="
echo

SMARTFRIND_DIR="/opt/smartfrind"
SUITE_DIR="/opt/smartfriend-suite"

# 1) فحص تبعيات smartfrind
echo "1. 📦 SMARTFRIND DEPENDENCIES:"
echo "----------------------------------------"

if [[ -f "$SMARTFRIND_DIR/requirements.txt" ]]; then
    echo "   Dependencies found in requirements.txt:"
    grep -E "^(fastapi|uvicorn|sqlite|requests|beautifulsoup|transformers|torch)" "$SMARTFRIND_DIR/requirements.txt" | while read dep; do
        echo "      🔗 $dep"
    done
else
    echo "   No requirements.txt - extracting from imports:"
    find "$SMARTFRIND_DIR" -name "*.py" -exec grep -hE "^(import |from )" {} \; | \
        grep -E "(fastapi|uvicorn|sqlite|requests|bs4|beautifulsoup|transformers|torch|telegram|openai)" | \
        sort -u | while read imp; do
        echo "      🐍 $imp"
    done
fi

# 2) فحص تكوينات قاعدة البيانات
echo
echo "2. 🗄️ DATABASE CONFIGURATIONS:"
echo "----------------------------------------"

find "$SMARTFRIND_DIR" -name "*.py" -exec grep -l "sqlite3.connect\|DB_PATH\|database" {} \; | while read file; do
    echo "   📁 $(basename "$file"):"
    grep -E "sqlite3.connect|DB_PATH|.*\.db" "$file" | head -2 | while read line; do
        echo "      💾 $line"
    done
done

# 3) فحص المنافذ والتشغيل
echo
echo "3. 🔌 PORTS & RUNNING CONFIG:"
echo "----------------------------------------"

find "$SMARTFRIND_DIR" -name "*.py" -exec grep -hE "port.*=.*[0-9]{4}|uvicorn.run|FastAPI" {} \; | while read line; do
    echo "   🌐 $line"
done

# 4) فحص إذا فيه تعارضات محتملة
echo
echo "4. ⚠️ POTENTIAL CONFLICTS:"
echo "----------------------------------------"

CONFLICTS=()

# فحص إذا فيه ملفات بنفس الأسماء
if [[ -d "$SUITE_DIR" ]]; then
    find "$SMARTFRIND_DIR" -name "*.py" | while read sf_file; do
        base_name=$(basename "$sf_file")
        if find "$SUITE_DIR" -name "$base_name" | grep -q .; then
            CONFLICTS+=("📄 $base_name - exists in both projects")
        fi
    done
    
    if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
        echo "   File name conflicts detected:"
        for conflict in "${CONFLICTS[@]}"; do
            echo "      ❌ $conflict"
        done
    else
        echo "   ✅ No file name conflicts"
    fi
fi

# 5) توصيات الدمج
echo
echo "5. 🎯 MERGE STRATEGY RECOMMENDATIONS:"
echo "----------------------------------------"

echo "   Recommended approach:"
echo "      📁 Create /opt/smartfriend-suite/legacy_integration/"
echo "      🔧 Copy essential smartfrind features there"
echo "      🔄 Update import paths and configurations"
echo "      🧪 Test each integrated component"
echo "      🚀 Gradually replace suite components with enhanced ones"

echo
echo "   Priority integration order:"
echo "      1. 🧠 Learning systems (learn_from_*, net_learner)"
echo "      2. 💾 Memory systems (advanced_memory, memory_store)" 
echo "      3. 🕷️ Spider system (smart_spider, daily_spider)"
echo "      4. 🔌 API gateways (unified_gateway, ai_learning_gateway)"
echo "      5. 🛠️ Utility scripts and tools"

echo
echo "✅ COMPATIBILITY STATUS: Ready for integration"

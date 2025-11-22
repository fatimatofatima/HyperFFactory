#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🔍 SmartFrind Analysis for Suite Integration"
echo "   📦 What to MERGE into smartfriend-suite"
echo "==============================================="
echo

SMARTFRIND_DIR="/opt/smartfrind"
SUITE_DIR="/opt/smartfriend-suite"

if [[ ! -d "$SMARTFRIND_DIR" ]]; then
    echo "❌ smartfrind directory not found!"
    exit 1
fi

echo "📊 SMARTFRIND INVENTORY:"
echo "----------------------------------------"

# 1) الميزات الرئيسية
echo "🎯 KEY FEATURES in smartfrind:"
find "$SMARTFRIND_DIR" -name "*.py" -type f | grep -E "(learn|memory|ai|bot|spider|gateway|api)" | while read file; do
    feature=$(basename "$file" .py)
    echo "   🔹 $feature - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
done

# 2) أنظمة التعلم المتقدمة
echo
echo "🧠 LEARNING SYSTEMS:"
find "$SMARTFRIND_DIR" -name "*.py" -path "*/learn*" -o -name "*learn*.py" | while read file; do
    size=$(wc -l < "$file")
    echo "   📚 $(basename "$file") - $size lines - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
    
    # عرض وصف مختصر من الملف
    head -5 "$file" | grep -E "def |class |\"\"\"" | head -2 | while read line; do
        echo "      💡 $line"
    done
done

# 3) أنظمة الذاكرة
echo
echo "💾 MEMORY SYSTEMS:"
find "$SMARTFRIND_DIR" -name "*memory*.py" -o -path "*/memory*" | while read file; do
    if [[ -f "$file" ]]; then
        echo "   🗂️  $(basename "$file") - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
    fi
done

# 4) البوابات وال APIs
echo
echo "🌐 APIS & GATEWAYS:"
find "$SMARTFRIND_DIR" -name "*gateway*.py" -o -name "*api*.py" | grep -v "__pycache__" | while read file; do
    port_line=$(grep -E "port.*=.*[0-9]{4}" "$file" | head -1)
    port=$(echo "$port_line" | grep -oE "[0-9]{4}" | head -1)
    echo "   🔌 $(basename "$file") - Port: ${port:-unknown} - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
done

# 5) قواعد البيانات والتكوين
echo
echo "🗄️ DATABASES & CONFIG:"
find "$SMARTFRIND_DIR" -name "*.db" -o -name "*.sqlite" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" | while read file; do
    if [[ -f "$file" ]]; then
        size=$(du -h "$file" | cut -f1)
        echo "   ⚙️  $(basename "$file") - $size - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
    fi
done

# 6) السكريبتات والأدوات
echo
echo "🛠️ SCRIPTS & TOOLS:"
find "$SMARTFRIND_DIR" -name "*.sh" -o -name "*.bash" | while read file; do
    if [[ -x "$file" ]]; then
        echo "   🔧 $(basename "$file") - executable - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
    else
        echo "   📝 $(basename "$file") - script - $(dirname "$file" | sed "s|$SMARTFRIND_DIR/||")"
    fi
done

# 7) فحص الـ requirements والتبعيات
echo
echo "📦 DEPENDENCIES:"
if [[ -f "$SMARTFRIND_DIR/requirements.txt" ]]; then
    echo "   📋 requirements.txt:"
    head -10 "$SMARTFRIND_DIR/requirements.txt" | while read req; do
        echo "      📍 $req"
    done
else
    echo "   ❌ No requirements.txt found"
    # البحث عن imports في الملفات
    echo "   🔍 Detected imports from code:"
    find "$SMARTFRIND_DIR" -name "*.py" -exec grep -E "^import |^from " {} \; | cut -d' ' -f2 | sort -u | head -10 | while read imp; do
        echo "      🐍 $imp"
    done
fi

echo
echo "🔍 COMPARISON WITH SUITE:"
echo "----------------------------------------"

if [[ -d "$SUITE_DIR" ]]; then
    echo "📊 Suite vs SmartFrind feature comparison:"
    
    # التعلم
    if find "$SUITE_DIR" -name "*learn*.py" | grep -q .; then
        echo "   ✅ Suite has learning systems"
    else
        echo "   ❌ Suite MISSING learning - COPY from smartfrind"
    fi
    
    # الذاكرة
    if find "$SUITE_DIR" -name "*memory*.py" | grep -q .; then
        echo "   ✅ Suite has memory systems" 
    else
        echo "   ❌ Suite MISSING memory - COPY from smartfrind"
    fi
    
    # الـ Spider
    if find "$SUITE_DIR" -name "*spider*.py" | grep -q .; then
        echo "   ✅ Suite has spider"
    else
        echo "   ❌ Suite MISSING spider - COPY from smartfrind"
    fi
else
    echo "❌ smartfriend-suite not found - may need to create it"
fi

echo
echo "🎯 MERGE RECOMMENDATIONS:"
echo "----------------------------------------"

# توصيات الدمج
RECOMMENDATIONS=()

# التعلم المتقدم
if find "$SMARTFRIND_DIR" -name "learn_from_curriculum.py" | grep -q .; then
    RECOMMENDATIONS+=("📚 Curriculum learning system")
fi

if find "$SMARTFRIND_DIR" -name "learn_from_premium_sources.py" | grep -q .; then
    RECOMMENDATIONS+=("🌐 Premium sources learning") 
fi

if find "$SMARTFRIND_DIR" -name "*spider*.py" | grep -q .; then
    RECOMMENDATIONS+=("🕷️ Web spider/crawler")
fi

if find "$SMARTFRIND_DIR" -name "*memory*.py" | grep -q .; then
    RECOMMENDATIONS+=("💾 Advanced memory systems")
fi

if find "$SMARTFRIND_DIR" -name "*gateway*.py" | grep -q .; then
    RECOMMENDATIONS+=("🔌 API gateways")
fi

echo "   Essential features to merge:"
for item in "${RECOMMENDATIONS[@]}"; do
    echo "      ✅ $item"
done

echo
echo "🚀 NEXT STEP: After this analysis, we'll create integration scripts"

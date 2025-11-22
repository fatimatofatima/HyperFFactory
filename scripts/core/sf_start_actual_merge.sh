#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🚀 بدء الدمج الفعلي - المرحلة 1"
echo "========================================== ======"
echo

SMARTFRIND_DIR="/opt/smartfrind"
SUITE_DIR="/opt/smartfriend-suite"
LEGACY_DIR="$SUITE_DIR/legacy_integration"

# 1) نسخ أنظمة التعلم
echo "1. 📚 نسخ أنظمة التعلم..."
LEARNING_FILES=(
    "learn_from_curriculum.py"
    "learn_from_premium_sources.py" 
    "learn_from_specific_urls.py"
    "interactive_learning.py"
)

for file in "${LEARNING_FILES[@]}"; do
    if [[ -f "$SMARTFRIND_DIR/$file" ]]; then
        cp "$SMARTFRIND_DIR/$file" "$LEGACY_DIR/learning_systems/"
        echo "   ✅ تم نسخ: $file"
        
        # تحديث مسارات قاعدة البيانات في الملف
        sed -i 's|/var/lib/smartfrind/smart_memory.db|/var/lib/smartfrind/smart_memory.db|g' "$LEGACY_DIR/learning_systems/$file"
    fi
done

# 2) نسخ الـ net_learner مع مجلده
echo
echo "2. 🕷️ نسخ Net Learner..."
if [[ -f "$SMARTFRIND_DIR/learner/net_learner.py" ]]; then
    cp "$SMARTFRIND_DIR/learner/net_learner.py" "$LEGACY_DIR/learning_systems/"
    echo "   ✅ تم نسخ: net_learner.py"
    
    # نسخ ملفات التكوين إذا وجدت
    if [[ -d "$SMARTFRIND_DIR/learner" ]]; then
        cp "$SMARTFRIND_DIR/learner/"*.txt "$LEGACY_DIR/learning_systems/" 2>/dev/null || true
        echo "   ✅ تم نسخ ملفات التكوين"
    fi
fi

# 3) نسخ أنظمة الذاكرة المتقدمة
echo
echo "3. 💾 نسخ أنظمة الذاكرة المتقدمة..."
MEMORY_FILES=(
    "app/smartfrind/advanced_memory.py"
    "app/smartfrind/memory_system.py"
    "app/smartfrind/smart_memory.py"
    "app/memory_store.py"
)

for file in "${MEMORY_FILES[@]}"; do
    if [[ -f "$SMARTFRIND_DIR/$file" ]]; then
        cp "$SMARTFRIND_DIR/$file" "$LEGACY_DIR/memory_systems/"
        echo "   ✅ تم نسخ: $(basename "$file")"
    fi
done

# 4) نسخ البوابات الرئيسية
echo
echo "4. 🌐 نسخ البوابات الرئيسية..."
GATEWAY_FILES=(
    "app/smartfrind/unified_gateway.py"
    "app/smartfrind/ai_learning_gateway.py"
)

for file in "${GATEWAY_FILES[@]}"; do
    if [[ -f "$SMARTFRIND_DIR/$file" ]]; then
        cp "$SMARTFRIND_DIR/$file" "$LEGACY_DIR/gateways/"
        echo "   ✅ تم نسخ: $(basename "$file")"
    fi
done

# 5) فحص الملفات المنقولة
echo
echo "5. 📊 فحص الملفات المنقولة:"
find "$LEGACY_DIR" -name "*.py" | while read file; do
    lines=$(wc -l < "$file")
    echo "   📄 $(basename "$file") - $lines سطر"
done

echo
echo "✅ اكتملت المرحلة 1 من الدمج!"
echo "🔜 التالي: تحديث مسارات الاستيراد والتكوين"

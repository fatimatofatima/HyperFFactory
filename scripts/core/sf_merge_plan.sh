#!/usr/bin/env bash
set -Eeuo pipefail

echo "==============================================="
echo "   🎯 خطة دمج SmartFrind في SmartFriend Suite"
echo "==============================================="
echo

SMARTFRIND_DIR="/opt/smartfrind"
SUITE_DIR="/opt/smartfriend-suite"

echo "🚀 خطة الدمج المنظمة:"
echo "----------------------------------------"

# 1) إنشاء مجلدات الدمج
echo "1. 📁 إنشاء هيكل الدمج في السويت:"
MERGE_DIRS=(
    "$SUITE_DIR/legacy_integration"
    "$SUITE_DIR/legacy_integration/learning_systems"
    "$SUITE_DIR/legacy_integration/memory_systems" 
    "$SUITE_DIR/legacy_integration/gateways"
    "$SUITE_DIR/legacy_integration/tools"
)

for dir in "${MERGE_DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "   ✅ تم إنشاء: $dir"
    else
        echo "   📁 موجود بالفعل: $dir"
    fi
done

# 2) قائمة الملفات للدمج
echo
echo "2. 📦 الملفات المطلوب دمجها:"

# أنظمة التعلم
LEARNING_FILES=(
    "learn_from_curriculum.py"
    "learn_from_premium_sources.py"
    "learn_from_specific_urls.py"
    "interactive_learning.py"
    "net_learner.py"
)

echo "   🧠 أنظمة التعلم:"
for file in "${LEARNING_FILES[@]}"; do
    sf_path="$SMARTFRIND_DIR/$file"
    if [[ -f "$sf_path" ]]; then
        echo "      🔹 $file"
    fi
done

# أنظمة الذاكرة
MEMORY_FILES=(
    "app/smartfrind/advanced_memory.py"
    "app/smartfrind/memory_system.py"
    "app/smartfrind/smart_memory.py"
    "app/memory_store.py"
)

echo "   💾 أنظمة الذاكرة:"
for file in "${MEMORY_FILES[@]}"; do
    sf_path="$SMARTFRIND_DIR/$file"
    if [[ -f "$sf_path" ]]; then
        echo "      🔹 $(basename "$file")"
    fi
done

# البوابات
GATEWAY_FILES=(
    "app/smartfrind/unified_gateway.py"
    "app/smartfrind/ai_learning_gateway.py"
    "app/smartfrind/simple_gateway.py"
)

echo "   🌐 البوابات:"
for file in "${GATEWAY_FILES[@]}"; do
    sf_path="$SMARTFRIND_DIR/$file"
    if [[ -f "$sf_path" ]]; then
        echo "      🔹 $(basename "$file")"
    fi
done

# 3) خطة التنفيذ
echo
echo "3. 🛠️ خطة التنفيذ:"
echo "   📝 الخطوة 1: نسخ الملفات إلى legacy_integration/"
echo "   📝 الخطوة 2: تحديث مسارات الاستيراد في الملفات"
echo "   📝 الخطوة 3: تحديث إعدادات قواعد البيانات"
echo "   📝 الخطوة 4: اختبار كل مكون مندمج"
echo "   📝 الخطوة 5: نقل المكونات الناجحة إلى packages/"

echo
echo "✅ جاهز للبدء في الدمج الفعلي!"

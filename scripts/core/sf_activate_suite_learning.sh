#!/usr/bin/env bash
set -Eeuo pipefail

echo "==========================================="
echo "    Activating Learning in SmartFriend Suite"
echo "==========================================="
echo

SUITE_DIR="/opt/smartfriend-suite"

if [[ ! -d "$SUITE_DIR" ]]; then
    echo "[FATAL] المسار $SUITE_DIR غير موجود"
    exit 1
fi

cd "$SUITE_DIR"

echo
echo "[1] فحص ملفات التعلم والسبايدر في السويت..."
LEARNING_FILES=(
    "bots/learn_from_curriculum.py"
    "bots/build_knowledge_base.py"
    "bots/learn_from_premium_sources.py"
    "bots/process_sources.py"
    "ingest/spider_core.py"
)

for file in "${LEARNING_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "  [+] $file - موجود"
        # عرض أول سطر غير تعليق (لو موجود)
        head -5 "$file" | grep -v '^[[:space:]]*#' | head -1 || true
    else
        echo "  [!] $file - غير موجود"
    fi
done

echo
echo "[2] تشغيل بناء قاعدة المعرفة (build_knowledge_base.py)..."
if [[ -f "bots/build_knowledge_base.py" ]]; then
    python3 bots/build_knowledge_base.py || {
        echo "[ERR] فشل build_knowledge_base.py"
        exit 1
    }
else
    echo "[SKIP] bots/build_knowledge_base.py غير موجود"
fi

echo
echo "[3] تشغيل التعلم من المناهج (learn_from_curriculum.py)..."
if [[ -f "bots/learn_from_curriculum.py" ]]; then
    python3 bots/learn_from_curriculum.py || {
        echo "[ERR] فشل learn_from_curriculum.py"
        exit 1
    }
else
    echo "[SKIP] bots/learn_from_curriculum.py غير موجود"
fi

echo
echo "[4] تشغيل التعلم من المصادر المميزة (learn_from_premium_sources.py) إن وجد..."
if [[ -f "bots/learn_from_premium_sources.py" ]]; then
    python3 bots/learn_from_premium_sources.py || {
        echo "[WARN] فشل learn_from_premium_sources.py – ليس قاتلاً، نكمل"
    }
else
    echo "[SKIP] bots/learn_from_premium_sources.py غير موجود"
fi

echo
echo "[5] تشغيل نظام معالجة المصادر (process_sources.py) إن وجد..."
if [[ -f "bots/process_sources.py" ]]; then
    python3 bots/process_sources.py || {
        echo "[WARN] فشل process_sources.py – نكمل"
    }
else
    echo "[SKIP] bots/process_sources.py غير موجود"
fi

echo
echo "[6] تشغيل نظام الزحف (ingest/spider_core.py)..."
if [[ -f "ingest/spider_core.py" ]]; then
    python3 ingest/spider_core.py || {
        echo "[ERR] فشل ingest/spider_core.py"
        exit 1
    }
else
    echo "[SKIP] ingest/spider_core.py غير موجود"
fi

echo
echo "==========================================="
echo "  تم تفعيل أنظمة التعلم والسبايدر في SmartFriend Suite"
echo "==========================================="

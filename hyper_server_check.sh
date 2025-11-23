#!/usr/bin/env bash
set -euo pipefail

BASE="/root/HyperFFactory"

echo "====================================="
echo " HyperFFactory - Server & Tree Check"
echo "====================================="
echo "Timestamp : $(date)"
echo "Hostname  : $(hostname)"
echo "Base Path : ${BASE}"
echo

# 1) فحص حالة السيرفر الأساسية
echo "---- [1] حالة السيرفر ----"
echo "📦 مساحة القرص على / :"
df -h / | sed -n '1,2p'
echo

echo "💾 الذاكرة:"
free -h
echo

echo "⏱️ مدة التشغيل:"
uptime
echo

# 2) فحص وجود المجلد الأساسي
echo "---- [2] فحص مسار HyperFFactory ----"
if [ ! -d "${BASE}" ]; then
    echo "❌ المجلد ${BASE} غير موجود."
    exit 1
fi

cd "${BASE}"

echo "📁 مجلدات أساسية متوقعة:"
for d in config stack ai apps db reports scripts src var; do
    if [ -d "${d}" ]; then
        echo "  ✅ ${d}/ موجود"
    else
        echo "  ⚠️ ${d}/ غير موجود"
    fi
done
echo

# 3) شجرة مختصرة للكود داخل HyperFFactory
echo "---- [3] شجرة مختصرة (py/sh فقط) ----"
find "${BASE}" -path "${BASE}/.git" -prune -o -type f \( -name "*.py" -o -name "*.sh" \) -print | head -40

CODE_COUNT=$(find "${BASE}" -path "${BASE}/.git" -prune -o -type f \( -name "*.py" -o -name "*.sh" \) -print | wc -l | tr -d ' ')
echo
echo "... (إجمالي ${CODE_COUNT} ملف كود *.py/*.sh داخل HyperFFactory)"
echo

# 4) عدّ إجمالي الملفات والمجلدات داخل HyperFFactory
echo "---- [4] إحصائيات المجلد ----"
DIR_COUNT=$(find "${BASE}" -path "${BASE}/.git" -prune -o -type d -print | wc -l | tr -d ' ')
FILE_COUNT=$(find "${BASE}" -path "${BASE}/.git" -prune -o -type f -print | wc -l | tr -d ' ')
echo "📊 عدد المجلدات (بدون .git): ${DIR_COUNT}"
echo "📊 عدد الملفات   (بدون .git): ${FILE_COUNT}"
echo

echo "✅ HyperFFactory server & tree check finished."

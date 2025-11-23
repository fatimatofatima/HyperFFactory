#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root/HyperFFactory"
IMPORTED_DIR="${ROOT_DIR}/imported"

echo "🔍 فحص سكربتات الفحص/الصحة/الإصلاح/التقارير داخل الريبوهات (snapshots) تحت: ${IMPORTED_DIR}"
echo

if [ ! -d "${IMPORTED_DIR}" ]; then
  echo "⚠️ مجلد imported/ غير موجود داخل ${ROOT_DIR} - لا يوجد Snapshots للريبوهات."
  exit 0
fi

# أنماط الأسماء المستهدفة (case-insensitive)
# health, check, diag, fix, repair, report, backup, snapshot
echo "📎 أنماط البحث: health / check / diag / fix / repair / report / backup / snapshot"
echo

# نجمع كل الملفات المطابقة
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

find "${IMPORTED_DIR}" -type f \
  \( \
    -iname '*health*'   -o \
    -iname '*check*'    -o \
    -iname '*diag*'     -o \
    -iname '*fix*'      -o \
    -iname '*repair*'   -o \
    -iname '*report*'   -o \
    -iname '*backup*'   -o \
    -iname '*snapshot*' \
  \) \
  2>/dev/null | sort > "${TMP_FILE}"

if ! [ -s "${TMP_FILE}" ]; then
  echo "ℹ️ لم يتم العثور على أي سكربتات مطابقة داخل imported/."
  exit 0
fi

echo "✅ تم العثور على $(wc -l < "${TMP_FILE}") سكربت/ملف مطابق."
echo
echo "📋 عرض السكربتات مجمّعة حسب الريبوه (smartfriend-suite / hyper-factory / ffactory / smartfrind / ...):"
echo

current_repo="__NONE__"

while IFS= read -r path; do
  repo="other"

  if   [[ "$path" == *"smartfriend-suite"* ]]; then
    repo="smartfriend-suite"
  elif [[ "$path" == *"HyperFFactory"* ]]; then
    repo="HyperFFactory"
  elif [[ "$path" == *"hyper-factory"* ]]; then
    repo="hyper-factory"
  elif [[ "$path" == *"ffactory2"* ]]; then
    repo="ffactory2"
  elif [[ "$path" == *"/ffactory"* ]]; then
    repo="ffactory"
  elif [[ "$path" == *"smartfrind"* ]]; then
    repo="smartfrind"
  fi

  if [[ "$repo" != "$current_repo" ]]; then
    current_repo="$repo"
    echo
    echo "=== REPO: ${repo} ==="
  fi

  # نطبع المسار كاملًا
  echo " - ${path}"
done < "${TMP_FILE}"

echo
echo "✅ انتهى الفحص المجمع للريبوهات."

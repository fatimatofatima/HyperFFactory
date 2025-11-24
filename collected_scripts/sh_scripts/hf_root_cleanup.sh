#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/root"
BASE_DIR="/root/HyperFFactory"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LEGACY_DIR="${BASE_DIR}/_root_legacy_${TIMESTAMP}"
LOG_DIR="${BASE_DIR}/logs"
REPORT_BEFORE="${LOG_DIR}/root_tree_before_${TIMESTAMP}.txt"
REPORT_AFTER="${LOG_DIR}/root_tree_after_${TIMESTAMP}.txt"
MOVED_LIST="${LEGACY_DIR}/moved_from_root_${TIMESTAMP}.txt"

mkdir -p "${LEGACY_DIR}" "${LOG_DIR}"

echo "=== HF Root Cleanup - ${TIMESTAMP} ==="
echo "BASE_DIR      : ${BASE_DIR}"
echo "LEGACY_DIR    : ${LEGACY_DIR}"
echo "LOG_DIR       : ${LOG_DIR}"
echo

if [[ ! -d "${BASE_DIR}" ]]; then
  echo "❌ BASE_DIR غير موجود: ${BASE_DIR}"
  exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
  echo "❌ هذا السكربت يجب أن يعمل بـ root"
  exit 1
fi

echo "[1] توثيق حالة /root قبل التنظيف..."
ls -Al "${ROOT_DIR}" > "${REPORT_BEFORE}"

echo "[2] تحديد العناصر التي سيتم نقلها من /root ..."
# نستثني:
#  - HyperFFactory نفسه
#  - أي عنصر يبدأ بـ .
# العمق مستوى واحد فقط
MAP_FILE="${LEGACY_DIR}/root_candidates_${TIMESTAMP}.txt"

find "${ROOT_DIR}" -mindepth 1 -maxdepth 1 \
  ! -path "${BASE_DIR}" \
  ! -name '.*' \
  -print | sort > "${MAP_FILE}"

if [[ ! -s "${MAP_FILE}" ]]; then
  echo "✅ لا يوجد عناصر لنقلها من /root (كل شيء مضبوط)."
  exit 0
fi

echo "سيتم نقل العناصر التالية إلى: ${LEGACY_DIR}"
cat "${MAP_FILE}"

echo
echo "[3] بدء النقل الفعلي إلى ${LEGACY_DIR} ..."
while IFS= read -r ITEM; do
  NAME="$(basename "${ITEM}")"
  echo "  → نقل: ${ITEM}  ==>  ${LEGACY_DIR}/${NAME}"
  mv "${ITEM}" "${LEGACY_DIR}/"
  echo "${ITEM} -> ${LEGACY_DIR}/${NAME}" >> "${MOVED_LIST}"
done < "${MAP_FILE}"

echo
echo "[4] توثيق حالة /root بعد التنظيف..."
ls -Al "${ROOT_DIR}" > "${REPORT_AFTER}"

echo
echo "=== ملخص العملية ==="
echo "✔️ مجلد الأرشيف  : ${LEGACY_DIR}"
echo "✔️ قائمة المنقول : ${MOVED_LIST}"
echo "✔️ تقرير قبل     : ${REPORT_BEFORE}"
echo "✔️ تقرير بعد     : ${REPORT_AFTER}"
echo
echo "تحقق يدويًا من /root:"
echo "  - يجب أن ترى HyperFFactory + الملفات المخفية فقط (.*)"
echo
echo "HF Root Cleanup: DONE"

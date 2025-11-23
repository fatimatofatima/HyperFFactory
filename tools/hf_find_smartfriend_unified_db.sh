#!/usr/bin/env bash
# HyperFFactory - فحص واكتشاف قواعد smartfriend_unified.db على السيرفر
# لا يقوم بأي نسخ أو استبدال، فقط تقرير.

set -euo pipefail

ROOT="/root/HyperFFactory"
OUT_DIR="${ROOT}/logs/db_probe"
mkdir -p "${OUT_DIR}"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="${OUT_DIR}/smartfriend_unified_candidates_${TS}.tsv"

echo "=================================================="
echo "🔎 HyperFFactory – فحص smartfriend_unified.db (قراءة فقط)"
echo "📍 Time : $(date '+%Y-%m-%d %H:%M:%S')"
echo "📂 Root : ${ROOT}"
echo "📄 Report: ${REPORT}"
echo "=================================================="
echo

# 1) إبلاغ عن وضع الملف الرسمي الحالي
OFFICIAL_DB="/opt/smartfriend-suite/var/db/smartfriend_unified.db"
if [[ -f "${OFFICIAL_DB}" ]]; then
  echo "✅ تم العثور على الملف الرسمي: ${OFFICIAL_DB}"
else
  echo "❌ الملف الرسمي غير موجود: ${OFFICIAL_DB}"
fi
echo

# 2) بناء قائمة أماكن البحث (نركّز على المسارات المنطقية)
SEARCH_ROOTS=(
  "/opt/smartfriend-suite"
  "/root/HyperFFactory"
  "/root"
  "/opt"
  "/var"
)

echo "📂 مسارات البحث:"
for p in "${SEARCH_ROOTS[@]}"; do
  echo "   - ${p}"
done
echo

# 3) تنفيذ find للبحث عن أي ملفات قريبة من smartfriend_unified.db
echo "🔍 بدء البحث عن ملفات قواعد محتملة..."
TMP_LIST="$(mktemp)"
trap 'rm -f "${TMP_LIST}"' EXIT

# نبحث عن أسماء قريبة من smartfriend_unified.db
find "${SEARCH_ROOTS[@]}" \
  -type f \( \
    -name 'smartfriend_unified.db' -o \
    -name 'smartfriend_unified.sqlite' -o \
    -name '*smartfriend*unified*.db' -o \
    -name '*smartfriend*unified*.sqlite' \
  \) 2>/dev/null > "${TMP_LIST}" || true

CAND_COUNT="$(wc -l < "${TMP_LIST}" || echo 0)"

if [[ "${CAND_COUNT}" -eq 0 ]]; then
  echo "⚠️ لم يتم العثور على أي ملفات مرشحة."
  echo "📄 لا يوجد تقرير مفيد، لكن تم إنشاء ملف فارغ: ${REPORT}"
  echo -e "path\tsize_bytes\tmtime\tintegrity" > "${REPORT}"
  exit 0
fi

echo "📦 عدد الملفات المرشحة: ${CAND_COUNT}"
echo

# 4) بناء التقرير TSV مع معلومات الحجم والتاريخ و integrity_check
echo -e "path\tsize_bytes\tmtime\tintegrity" > "${REPORT}"

HAS_SQLITE3=0
if command -v sqlite3 >/dev/null 2>&1; then
  HAS_SQLITE3=1
else
  echo "ℹ️ sqlite3 غير متوفر – سيتم تخطي فحص PRAGMA integrity_check."
  echo
fi

while IFS= read -r FILE; do
  [[ -z "${FILE}" ]] && continue

  SIZE="$(stat -c '%s' "${FILE}" 2>/dev/null || echo '?')"
  MTIME="$(stat -c '%y' "${FILE}" 2>/dev/null || echo '?')"
  INTEGRITY="NA"

  if [[ "${HAS_SQLITE3}" -eq 1 ]]; then
    # نحاول PRAGMA integrity_check
    IC_OUT="$(sqlite3 "${FILE}" 'PRAGMA integrity_check;' 2>/dev/null || echo 'ERROR')"
    # نأخذ أول سطر فقط
    INTEGRITY="$(echo "${IC_OUT}" | head -n1 | tr -d '\r\n')"
    [[ -z "${INTEGRITY}" ]] && INTEGRITY="UNKNOWN"
  fi

  echo -e "${FILE}\t${SIZE}\t${MTIME}\t${INTEGRITY}" >> "${REPORT}"

done < "${TMP_LIST}"

echo "✅ الفحص انتهى."
echo "📄 تقرير المرشحين محفوظ في:"
echo "    ${REPORT}"
echo
echo "💡 لعرضه بشكل جدولي:"
echo "    column -t -s$'\t' \"${REPORT}\" | less -S"
echo
echo "⚠️ السكربت لا يقوم بأي نسخ/استبدال. القرار النهائي في يدك لاختيار الملف الرسمي."
echo "=================================================="

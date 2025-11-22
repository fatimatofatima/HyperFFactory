#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-LEGACY-P1]"
OUT_DIR="/opt/smartfriend-suite/reports"

echo "${LOG_TAG} البحث عن أحدث ملف قرارات..."
DEC_FILE="$(ls -1 ${OUT_DIR}/sf_suite_service_decisions_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${DEC_FILE}" ]] || [[ ! -f "${DEC_FILE}" ]]; then
  echo "${LOG_TAG} لم يتم العثور على أي ملف قرارات في ${OUT_DIR}"
  exit 1
fi

echo "${LOG_TAG} استخدام ملف القرارات: ${DEC_FILE}"
echo

# تنبيه أمان
echo "هذا السكربت سيطبق القرارات على خدمات smartfrind فقط:"
echo "  - KEEP_BACKEND_ONLY  => enable --now"
echo "  - DEPRECATE_LATER    => stop + disable"
echo
read -r -p "متابعة؟ (type YES للمتابعة): " CONFIRM
if [[ "${CONFIRM}" != "YES" ]]; then
  echo "${LOG_TAG} تم الإلغاء من قبل المستخدم."
  exit 0
fi

echo
echo "=========== تفعيل smartfrind (KEEP_BACKEND_ONLY) ==========="
awk -F'\t' 'NR>1 && $1=="smartfrind" && $10=="KEEP_BACKEND_ONLY" {print $2}' "${DEC_FILE}" | sort -u | while read -r unit; do
  [[ -z "${unit}" ]] && continue
  echo "${LOG_TAG} [KEEP_BACKEND_ONLY] enabling & starting: ${unit}"
  systemctl enable --now "${unit}" || echo "${LOG_TAG} WARNING: فشل enable/now لـ ${unit}"
done

echo
echo "=========== إيقاف smartfrind (DEPRECATE_LATER) ============="
awk -F'\t' 'NR>1 && $1=="smartfrind" && $10=="DEPRECATE_LATER" {print $2}' "${DEC_FILE}" | sort -u | while read -r unit; do
  [[ -z "${unit}" ]] && continue
  echo "${LOG_TAG} [DEPRECATE_LATER] stopping: ${unit}"
  systemctl stop "${unit}" || echo "${LOG_TAG} WARNING: فشل stop لـ ${unit}"
  echo "${LOG_TAG} [DEPRECATE_LATER] disabling: ${unit}"
  systemctl disable "${unit}" || echo "${LOG_TAG} WARNING: فشل disable لـ ${unit}"
done

echo
echo "${LOG_TAG} Phase 1 لا يغيّر أي وحدة family=suite. فقط smartfrind."
echo "${LOG_TAG} DONE."

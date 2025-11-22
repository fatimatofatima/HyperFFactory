#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

LOG_TAG="[SF-SUMMARY]"
OUT_DIR="/opt/smartfriend-suite/reports"

echo "${LOG_TAG} البحث عن أحدث ملف قرارات..."
DEC_FILE="$(ls -1 ${OUT_DIR}/sf_suite_service_decisions_*.tsv 2>/dev/null | sort | tail -n 1 || true)"

if [[ -z "${DEC_FILE}" ]] || [[ ! -f "${DEC_FILE}" ]]; then
  echo "${LOG_TAG} لم يتم العثور على أي ملف قرارات في ${OUT_DIR}"
  exit 1
fi

echo "${LOG_TAG} استخدام ملف القرارات: ${DEC_FILE}"
echo

echo "================= SUMMARY: Counts per decision ================="
awk -F'\t' 'NR>1 { c[$10]++ } END { for (d in c) printf "%-18s %4d\n", d, c[d] }' "${DEC_FILE}" | sort
echo

echo "=========== SUMMARY: Counts per (family, decision) ============="
awk -F'\t' 'NR>1 { key=$1 " / " $10; c[key]++ } END { for (k in c) printf "%-30s %4d\n", k, c[k] }' "${DEC_FILE}" | sort
echo

for decision in KEEP KEEP_BACKEND_ONLY DEPRECATE_LATER REVIEW; do
  echo "---------------------- ${decision} ----------------------"
  awk -F'\t' -v d="${decision}" 'NR==1 {header=$0; next} $10==d {printf "%-10s %-40s %-10s %-12s %-10s\n", $1, $2, $3, $4, $5}' "${DEC_FILE}" | sort
  echo
done

echo "${LOG_TAG} DONE."

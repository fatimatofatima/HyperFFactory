#!/usr/bin/env bash
# HyperFFactory - فحص شامل لكل قواعد البيانات (legacy + runtime)

set -u -o pipefail

ROOT="/root/HyperFFactory"
DB_HEALTH_DIR="${ROOT}/logs/db_health"
mkdir -p "${DB_HEALTH_DIR}"

TS="$(date +%Y%m%d_%H%M%S)"
LOG="${DB_HEALTH_DIR}/db_health_${TS}.log"
SUMMARY="${DB_HEALTH_DIR}/db_health_summary_${TS}.tsv"

DB_PATHS=(
  "/root/HyperFFactory/all_legacy_dbs"
  "/opt/hyper-factory/var/db"
)

echo "🚀 HyperFFactory - DB Health Check"          | tee "${LOG}"
echo "======================================"    | tee -a "${LOG}"
echo "Started at: $(date -Iseconds)"            | tee -a "${LOG}"
echo "Roots:"                                   | tee -a "${LOG}"
for p in "${DB_PATHS[@]}"; do
  echo "  - ${p}"                               | tee -a "${LOG}"
done
echo ""                                         | tee -a "${LOG}"

# ملف مؤقت لتجميع كل المسارات (دعم الأسماء التي تحتوي على مسافات)
TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT

for base in "${DB_PATHS[@]}"; do
  if [ -d "$base" ]; then
    find "$base" -type f \( -name "*.db" -o -name "*.sqlite" \) -print0 >> "$TMP_LIST"
  fi
done

TOTAL=0
OK_COUNT=0
WARN_COUNT=0
ERROR_COUNT=0

# ملخص TSV: path,origin,size_mb,status,num_tables,note
echo -e "path\torigin\tsize_mb\tstatus\tnum_tables\tnote" > "${SUMMARY}"

while IFS= read -r -d '' DB_FILE; do
  TOTAL=$((TOTAL + 1))

  ORIGIN="other"
  case "${DB_FILE}" in
    /root/HyperFFactory/all_legacy_dbs/*)
      ORIGIN="legacy"
      ;;
    /opt/hyper-factory/var/db/identity/*)
      ORIGIN="runtime_identity"
      ;;
    /opt/hyper-factory/var/db/memory/*)
      ORIGIN="runtime_memory"
      ;;
    /opt/hyper-factory/var/db/knowledge/*)
      ORIGIN="runtime_knowledge"
      ;;
    /opt/hyper-factory/var/db/*)
      ORIGIN="runtime_other"
      ;;
  esac

  # حجم الملف بالبايت → MB
  SIZE_BYTES="$(stat -c '%s' "${DB_FILE}" 2>/dev/null || echo 0)"
  SIZE_MB="$(awk -v s="${SIZE_BYTES}" 'BEGIN { printf "%.2f", (s / (1024*1024)) }')"

  echo "----------------------------------------"    >> "${LOG}"
  echo "📦 DB #${TOTAL}"                             >> "${LOG}"
  echo "  Path   : ${DB_FILE}"                      >> "${LOG}"
  echo "  Origin : ${ORIGIN}"                       >> "${LOG}"
  echo "  Size   : ${SIZE_MB} MB"                   >> "${LOG}"

  STATUS="UNKNOWN"
  NOTE=""

  # quick_check
  rc=0
  QUICK_OUT="$(sqlite3 "${DB_FILE}" 'PRAGMA quick_check;' 2>&1)" || rc=$?

  if [ "${rc}" -ne 0 ]; then
    STATUS="ERROR"
    NOTE="sqlite_error: ${QUICK_OUT:0:120}"
    ERROR_COUNT=$((ERROR_COUNT + 1))
    echo "  ❌ quick_check ERROR: ${QUICK_OUT}"      >> "${LOG}"
  else
    # sqlite رجّعت خروج سليم – نفحص النص
    if [ "${QUICK_OUT}" = "ok" ]; then
      STATUS="OK"
      NOTE="quick_check_ok"
      OK_COUNT=$((OK_COUNT + 1))
      echo "  ✅ quick_check: ok"                    >> "${LOG}"
    else
      STATUS="WARN"
      NOTE="quick_check_output: ${QUICK_OUT:0:120}"
      WARN_COUNT=$((WARN_COUNT + 1))
      echo "  ⚠️ quick_check WARN: ${QUICK_OUT}"    >> "${LOG}"
    fi
  fi

  # عدد الجداول إن أمكن
  NUM_TABLES="NA"
  if sqlite3 "${DB_FILE}" "SELECT name FROM sqlite_master WHERE type='table' LIMIT 1;" >/dev/null 2>&1; then
    NUM_TABLES="$(sqlite3 "${DB_FILE}" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "NA")"
  fi
  echo "  Tables : ${NUM_TABLES}"                   >> "${LOG}"
  echo "  Status : ${STATUS}"                       >> "${LOG}"
  echo "  Note   : ${NOTE}"                         >> "${LOG}"

  # ملخص TSV
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "${DB_FILE}" "${ORIGIN}" "${SIZE_MB}" "${STATUS}" "${NUM_TABLES}" "${NOTE}" >> "${SUMMARY}"

done < "${TMP_LIST}"

echo "----------------------------------------"      | tee -a "${LOG}"
echo "📊 Summary:"                                   | tee -a "${LOG}"
echo "  Total DBs : ${TOTAL}"                       | tee -a "${LOG}"
echo "  OK        : ${OK_COUNT}"                    | tee -a "${LOG}"
echo "  WARN      : ${WARN_COUNT}"                  | tee -a "${LOG}"
echo "  ERROR     : ${ERROR_COUNT}"                 | tee -a "${LOG}"
echo ""                                             | tee -a "${LOG}"
echo "📁 Log file     : ${LOG}"                     | tee -a "${LOG}"
echo "📁 Summary TSV  : ${SUMMARY}"                 | tee -a "${LOG}"
echo "✅ Completed at : $(date -Iseconds)"          | tee -a "${LOG}"

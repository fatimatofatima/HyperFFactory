#!/usr/bin/env bash
# HyperFFactory - مسح سكربتات العقل/الذاكرة/المهام/العمال/قواعد البيانات/الجودة
# باستخدام 6 أنوية + شريط تقدم

set -euo pipefail

############################################
# إعدادات عامة
############################################

ROOT="/root/HyperFFactory"
OUT_DIR="${ROOT}/logs/scan_brain_memory"
mkdir -p "${OUT_DIR}"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="${OUT_DIR}/brain_memory_scan_${TS}.tsv"
PROGRESS_LOG="${OUT_DIR}/brain_memory_scan_${TS}.progress"
PROGRESS_LOCK="${OUT_DIR}/brain_memory_scan_${TS}.progress.lock"
REPORT_LOCK="${OUT_DIR}/brain_memory_scan_${TS}.report.lock"

# عدد الأنوية المستخدمة
CPUS=6

# جذور البحث (مشاريع فقط – بدون مجلدات النظام)
SEARCH_ROOTS=(
  "/root/HyperFFactory"
  "/opt/hyper-factory"
  "/opt/smartfriend-suite"
  "/etc/smartfriend"
  "/etc/systemd/system"
)

# أنماط الكلمات المستهدفة (اسم الملف + المحتوى)
PATTERNS="brain|neural|memory|identity|awareness|task|queue|worker|workers|agent|agents|job|jobs|scheduler|cron|pipeline|pipelines|quality|score|scores|metric|metrics|validator|validation|db|database|databases|sqlite|postgres|neo4j"

############################################
# طباعة رأس التقرير
############################################
echo -e "type\tmatch\tpath" > "${REPORT}"

############################################
# بناء قائمة الملفات المرشحة
############################################
TMP_LIST="$(mktemp)"
trap 'rm -f "${TMP_LIST}"' EXIT

echo "=== HyperFFactory - مسح سكربتات العقل/الذاكرة/المهام/العمال/الجودة (6 أنوية) ==="
echo "📁 تقرير: ${REPORT}"
echo
echo "🔍 بناء قائمة الملفات المرشحة..."

for base in "${SEARCH_ROOTS[@]}"; do
  [ -d "$base" ] || continue

  find "$base" \
    -type f \
    \( \
      -name "*.sh" -o \
      -name "*.bash" -o \
      -name "*.py" -o \
      -name "*.service" -o \
      -name "*.timer" -o \
      -name "docker-compose*.yml" -o \
      -name "*.yaml" -o \
      -name "*.yml" -o \
      -name "*.ini" -o \
      -name "*.env" -o \
      -name "*.conf" \
    \) \
    ! -path "*/.git/*" \
    ! -path "*/venv/*" \
    ! -path "*/.venv/*" \
    ! -path "*/env/*" \
    ! -path "*/__pycache__/*" \
    ! -path "*/node_modules/*" \
    >> "${TMP_LIST}" 2>/dev/null || true
done

if ! [ -s "${TMP_LIST}" ]; then
  echo "⚠️ لم يتم العثور على أي ملفات مرشحة في جذور البحث المحددة."
  echo "انتهى."
  exit 0
fi

TOTAL_FILES="$(wc -l < "${TMP_LIST}")"
echo "📦 عدد الملفات المرشحة: ${TOTAL_FILES}"
echo "total_files=${TOTAL_FILES}" > "${PROGRESS_LOG}"
echo "processed=0" >> "${PROGRESS_LOG}"

############################################
# دالة تحديث شريط التقدم
############################################
update_progress() {
  # تستخدم flock لضمان تحديث متسق للشريط من 6 أنوية
  {
    flock 200

    # تحميل الحالة الحالية
    if [ -f "${PROGRESS_LOG}" ]; then
      # shellcheck disable=SC1090
      . "${PROGRESS_LOG}"
    else
      total_files=${TOTAL_FILES}
      processed=0
    fi

    processed=$((processed + 1))

    {
      echo "total_files=${total_files}"
      echo "processed=${processed}"
    } > "${PROGRESS_LOG}"

    pct=0
    if [ "${total_files}" -gt 0 ]; then
      pct=$(( processed * 100 / total_files ))
    fi

    printf "\r⏳ Progress: %d/%d (%d%%)" "${processed}" "${total_files}" "${pct}"
  } 200>"${PROGRESS_LOCK}"
}

############################################
# دالة فحص ملف واحد
############################################
scan_one_file() {
  local path="$1"
  local lower_path
  lower_path="$(printf '%s' "$path" | tr 'A-Z' 'a-z')"
  local matched=0

  # 1) فحص اسم الملف/المسار
  if printf '%s\n' "${lower_path}" | grep -Eq "${PATTERNS}"; then
    matched=1
    {
      flock 201
      printf "path_match\t%s\t%s\n" "${PATTERNS}" "${path}" >> "${REPORT}"
    } 201>"${REPORT_LOCK}"
  fi

  # 2) فحص محتوى الملف (نص فقط – نتجاهل الأخطاء)
  if grep -Eq "${PATTERNS}" "$path" 2>/dev/null; then
    matched=1
    {
      flock 201
      printf "content_match\t%s\t%s\n" "${PATTERNS}" "${path}" >> "${REPORT}"
    } 201>"${REPORT_LOCK}"
  fi

  # 3) تحديث شريط التقدم
  update_progress
}

export PATTERNS REPORT PROGRESS_LOG PROGRESS_LOCK REPORT_LOCK TOTAL_FILES
export -f update_progress
export -f scan_one_file

############################################
# تنفيذ الفحص باستخدام 6 أنوية
############################################
echo
echo "🚀 بدء الفحص المتوازي باستخدام ${CPUS} أنوية..."
echo

# إذا كان parallel متوفر، استخدمه مع شريط التقدم الخاص به
if command -v parallel >/dev/null 2>&1; then
  echo "✅ GNU parallel متوفر – استخدام parallel --jobs ${CPUS} --bar"
  cat "${TMP_LIST}" | parallel --jobs "${CPUS}" --bar scan_one_file {}
else
  echo "ℹ️ GNU parallel غير متوفر – استخدام xargs -P ${CPUS} مع شريط تقدم مخصص"
  cat "${TMP_LIST}" \
    | tr '\n' '\0' \
    | xargs -0 -P "${CPUS}" -n 1 bash -lc 'scan_one_file "$0"' 
fi

echo
echo
echo "✅ الفحص انتهى."

############################################
# ملخص النتائج
############################################
MATCHES=$(( $(wc -l < "${REPORT}") - 1 ))
[ "${MATCHES}" -lt 0 ] && MATCHES=0

echo "📊 عدد الصفوف المطابقة (بدون الهيدر): ${MATCHES}"
echo "📁 التقرير النهائي: ${REPORT}"
echo
echo "💡 يمكن فتح التقرير بـ:"
echo "    column -t -s$'\\t' \"${REPORT}\" | less -S"

#!/usr/bin/env bash
# HyperFFactory – Workers Inventory & Layout Report
# - يحصر كل ما يخص "العمال" (workers) في الشجرة الموحدة.
# - يركّز على:
#   1) مجلد workers/ إن وجد.
#   2) سكربتات العمال أو إدارة العمال (worker / workers في الاسم).
#   3) السكربتات التي تشير إلى workers في المحتوى.

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="reports/hf_workers_inventory_${TS}.log"
mkdir -p reports

header() {
  echo "==================================================" | tee -a "$REPORT"
  echo "🧩 HyperFFactory – Workers Inventory & Layout" | tee -a "$REPORT"
  echo "ROOT : ${ROOT}" | tee -a "$REPORT"
  echo "TIME : ${TS}" | tee -a "$REPORT"
  echo "==================================================" | tee -a "$REPORT"
  echo | tee -a "$REPORT"
}

divider() {
  echo "--------------------------------------------------" | tee -a "$REPORT"
}

check_workers_dir() {
  echo "## 1) workers/ directory (core workers layout)" | tee -a "$REPORT"
  divider
  if [ -d "workers" ]; then
    echo "[OK]  workers/ موجود." | tee -a "$REPORT"
    echo | tee -a "$REPORT"
    echo "محتوى workers/ (عمق 2 – سكربتات فقط):" | tee -a "$REPORT"
    echo | tee -a "$REPORT"
    find workers -maxdepth 2 \
      \( -name "*.sh" -o -name "*.py" \) \
      -printf "  - %p\n" 2>/dev/null | tee -a "$REPORT" || true
  else
    echo "[MISS] لا يوجد مجلد workers/ في الجذر." | tee -a "$REPORT"
  fi
  echo | tee -a "$REPORT"
}

find_worker_named_scripts() {
  echo "## 2) ملفات باسم يحتوي worker / workers (في الاسم)" | tee -a "$REPORT"
  divider

  # استبعاد المسارات الثقيلة/الأرشيفية
  EXCLUDES=(
    "./.git"
    "./backups_legacy"
    "./imported"
    "./opt/_root_legacy_2025"
    "./_root_legacy_2025"
  )

  FIND_CMD=(find . -type f \( -name "*worker*.sh" -o -name "*workers*.sh" -o -name "*worker*.py" -o -name "*workers*.py" \))

  for ex in "${EXCLUDES[@]}"; do
    FIND_CMD+=( -not -path "${ex}/*" )
  done

  # تنفيذ الأمر
  WORKER_FILES=$("${FIND_CMD[@]}" 2>/dev/null || true)

  if [ -z "${WORKER_FILES}" ]; then
    echo "[INFO] لا توجد ملفات سكربت باسم worker*/workers* (داخل الشجرة الأساسية بعد الاستبعاد)." | tee -a "$REPORT"
  else
    echo "[OK] تم العثور على سكربتات مرتبطة بالعمال (بالاسم):" | tee -a "$REPORT"
    echo "${WORKER_FILES}" | sed 's/^/  - /' | tee -a "$REPORT"
  fi

  echo | tee -a "$REPORT"
}

find_worker_manager_scripts() {
  echo "## 3) سكربتات إدارة العمال (hf_workers_manager / dashboard / task board)" | tee -a "$REPORT"
  divider

  # نركّز على collected_scripts_from_opt + scripts + tools + bin
  TARGET_DIRS=(
    "workers"
    "scripts"
    "tools"
    "bin"
    "collected_scripts_from_opt"
  )

  MATCH_PATTERNS=(
    "hf_workers_manager"
    "workers_manager"
    "worker_manager"
    "workers dashboard"
    "task_board"
  )

  FOUND_ANY=false

  for d in "${TARGET_DIRS[@]}"; do
    [ -d "$d" ] || continue
    for pat in "${MATCH_PATTERNS[@]}"; do
      RES=$(grep -RIl "$pat" "$d" 2>/dev/null || true)
      if [ -n "$RES" ]; then
        if [ "$FOUND_ANY" = false ]; then
          echo "[OK] تم العثور على سكربتات إدارة/لوحات مرتبطة بالعمال:" | tee -a "$REPORT"
          FOUND_ANY=true
        fi
        echo "$RES" | sort -u | sed "s/^/  - /" | tee -a "$REPORT"
      fi
    done
  done

  if [ "$FOUND_ANY" = false ]; then
    echo "[INFO] لا توجد إشارات واضحة لسكربتات إدارة العمال في المسارات المستهدفة." | tee -a "$REPORT"
  fi

  echo | tee -a "$REPORT"
}

grep_workers_refs() {
  echo "## 4) ملفات تشير إلى workers في المحتوى (كلمة workers / worker)" | tee -a "$REPORT"
  divider

  TARGET_DIRS=(
    "workers"
    "scripts"
    "tools"
    "bin"
    "ai"
    "apps"
  )

  TMP_FILE="$(mktemp)"
  trap 'rm -f "$TMP_FILE"' EXIT

  for d in "${TARGET_DIRS[@]}"; do
    [ -d "$d" ] || continue
    grep -RIn "workers" "$d" 2>/dev/null >> "$TMP_FILE" || true
    grep -RIn "worker" "$d" 2>/dev/null >> "$TMP_FILE" || true
  done

  if [ ! -s "$TMP_FILE" ]; then
    echo "[INFO] لا توجد إشارات نصية واضحة لكلمة worker(s) في المسارات المستهدفة." | tee -a "$REPORT"
  else
    echo "[INFO] مراجع نصية لـ worker(s) (أول 100 سطر):" | tee -a "$REPORT"
    head -n 100 "$TMP_FILE" | sed 's/^/  /' | tee -a "$REPORT"
  fi

  echo | tee -a "$REPORT"
}

summary_section() {
  echo "## 5) ملخص تنفيذي – وضع العمال" | tee -a "$REPORT"
  divider
  if [ -d "workers" ]; then
    echo "- workers/: موجود (راجع القسم 1 للتفاصيل)." | tee -a "$REPORT"
  else
    echo "- workers/: غير موجود – يمكن إنشاؤه لاحقًا لاستضافة العمال الرسميين." | tee -a "$REPORT"
  fi
  echo "- راجع التقرير بالكامل في: ${REPORT}" | tee -a "$REPORT"
  echo | tee -a "$REPORT"
}

# تشغيل
header
check_workers_dir
find_worker_named_scripts
find_worker_manager_scripts
grep_workers_refs
summary_section

echo "تم حفظ تقرير العمال في: ${REPORT}"

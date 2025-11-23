#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------
# HyperFFactory – كتالوج السكربتات الأساسية (hyper_*)
# ---------------------------------------------------------

ROOT="/root/HyperFFactory"
WATCH=0

# معالجة الخيارات البسيطة
while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --watch)
      WATCH=1
      shift
      ;;
    --root=*)
      ROOT="${1#*=}"
      shift
      ;;
    *)
      echo "استخدام: $0 [--watch] [--root=/path/to/HyperFFactory]"
      exit 1
      ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  echo "❌ مجلد HyperFFactory غير موجود: $ROOT"
  exit 1
fi

# ----------------- تعريف الفئات والسكربتات -----------------

# فئة A: قواعد البيانات / الميتا / النسخ الاحتياطي
DB_SCRIPTS=(
  "hyper_collect_all_dbs.sh"
  "hyper_db_audit_readonly.sh"
  "hyper_db_safe_backup_from_meta.sh"
  "hyper_db_usage_from_meta.sh"
  "hyper_scan_dbs.sh"
  "hyper_meta_build_db_meta.sh"
  "hyper_dedupe_by_hash.sh"
)

# فئة B: الهوية / المعرفة / الدمج من الأنظمة القديمة
IDENTITY_SCRIPTS=(
  "hyper_fix_identity_roles_schema.sh"
  "hyper_identity_init.sh"
  "hyper_identity_seed.sh"
  "hyper_init_brain_and_knowledge.sh"
  "hyper_init_brain_and_knowledge_v2.sh"
  "hyper_migrate_identity_from_legacy.sh"
  "hyper_migrate_knowledge_from_legacy.sh"
  "hyper_init_workers_tables.sh"
  "hyper_seed_tasks_basics.sh"
  "hyper_seed_workers_from_services.sh"
  "hyper_seed_runtime_from_legacy.sh"
)

# فئة C: التهيئة العامة / البنية / التشغيل
ENV_SCRIPTS=(
  "hyper_init_data_home.sh"
  "hyper_init_runtime_dbs.sh"
  "setup_hyper_ffactory.sh"
  "show_structure.sh"
  "emergency_restore.sh"
)

print_header() {
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================================"
  echo "📂 HyperFFactory – كتالوج السكربتات الأساسية (hyper_*)"
  echo "⏱  الوقت الحالي: $now"
  echo "📍 الجذر: $ROOT"
  echo "============================================================"
}

print_category() {
  local title="$1"; shift
  local -a names=("$@")
  local idx=1

  echo
  echo "[$title]"
  for fname in "${names[@]}"; do
    if [ -f "$ROOT/$fname" ]; then
      printf "   %d) %s\n" "$idx" "$fname"
      ALL_EXISTING+=("$fname")
      idx=$((idx+1))
    else
      printf "   - (مفقود) %s\n" "$fname"
    fi
  done
}

do_print() {
  # مصفوفة لتجميع جميع الملفات الموجودة فعليًا لمرحلة التفاصيل المتوازية
  ALL_EXISTING=()

  print_header

  print_category "A: سكربتات قواعد البيانات والنسخ الاحتياطي" \
    "${DB_SCRIPTS[@]}"

  print_category "B: سكربتات الهوية/المعرفة والهجرة من الأنظمة القديمة" \
    "${IDENTITY_SCRIPTS[@]}"

  print_category "C: سكربتات التهيئة العامة والبنية والتشغيل" \
    "${ENV_SCRIPTS[@]}"

  # ----------------- تفاصيل مختصرة باستخدام 6 أنوية -----------------
  if [ "${#ALL_EXISTING[@]}" -gt 0 ] && command -v xargs >/dev/null 2>&1; then
    echo
    echo "تفاصيل مختصرة (آخر تعديل + الحجم + المسار) – باستخدام 6 أنوية:"

    # نبني قائمة المسارات الكاملة ثم نمررها إلى ls عبر xargs -P 6
    printf "%s\n" "${ALL_EXISTING[@]}" \
      | while read -r rel; do
          f="$ROOT/$rel"
          [ -f "$f" ] && printf '%s\n' "$f"
        done \
      | xargs -P 6 -n 1 ls -lh --time-style=long-iso 2>/dev/null \
      | awk '
        {
          # بناء الاسم الكامل (في حال وجود مسافات)
          name="";
          for (i=9;i<=NF;i++) {
            name = name (i==9 ? "" : " ") $i
          }
          printf "  - %s %s  %6s  %s\n", $6, $7, $5, name
        }'
  fi

  echo
}

if [ "$WATCH" -eq 1 ]; then
  while true; do
    clear
    do_print
    echo "🔁 وضع المتابعة المستمرة (Ctrl+C للخروج) – التحديث كل 15 ثانية"
    echo "============================================================"
    sleep 15
  done
else
  do_print
fi

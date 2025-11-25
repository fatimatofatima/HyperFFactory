#!/usr/bin/env bash
set -euo pipefail

cd /root/HyperFFactory

PLAN_FILE="plans/HF_EXEC_PLAN.tsv"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "❌ ملف الخطة غير موجود: $PLAN_FILE"
  echo "↪ أنشئه أولاً أو تأكد من المسار."
  exit 1
fi

print_once() {
  local now
  now="$(date +'%Y-%m-%d %H:%M:%S')"

  echo "============================================================"
  echo "🚀 خطة عمل HyperFFactory – حالة التنفيذ"
  echo "⏱  الوقت الحالي: $now"
  echo "📄 ملف الخطة   : $PLAN_FILE"
  echo "============================================================"
  echo

  # ملخص الحالة
  awk -F'\t' 'NR==1 {next}
  {
    total++
    status=$5
    count[status]++
  }
  END {
    printf "📊 ملخص سريع:\n"
    printf "  • إجمالي المهام        : %d\n", total
    printf "  • ✅ منجَز (DONE)       : %d\n", (count["DONE"]+0)
    printf "  • 🟡 قيد التنفيذ        : %d\n", (count["IN_PROGRESS"]+0)
    printf "  • ⬜ متبقّي (TODO)      : %d\n", (count["TODO"]+0)
    printf "  • ⛔ متوقف (BLOCKED)    : %d\n", (count["BLOCKED"]+0)
    printf "\n"
  }' "$PLAN_FILE"

  echo "📌 تفاصيل حسب المهام:"
  echo

  # عرض المهام سطر بسطر
  awk -F'\t' '
  NR==1 {next}
  {
    id=$1; stage=$2; cat=$3; task=$4; status=$5; owner=$6; note=$7
    icon="⬜"; label="TODO"
    if (status=="DONE")        {icon="✅"; label="منجَز"}
    else if (status=="IN_PROGRESS") {icon="🟡"; label="قيد التنفيذ"}
    else if (status=="BLOCKED")     {icon="⛔"; label="متوقف"}

    printf "%s [%s] (%s) {%s}\n    - %s\n    - مسؤول: %s | ملاحظة: %s\n\n",
           icon, stage, id, cat, task, owner, (note=="" ? "-" : note)
  }' "$PLAN_FILE"
}

main() {
  local mode="${1:-once}"

  case "$mode" in
    --loop|loop|watch)
      local interval="${2:-10}" # ثانية بين كل تحديث
      while true; do
        clear
        print_once
        echo "🔁 وضع المتابعة المستمرة (Ctrl+C للخروج) – التحديث كل ${interval} ثانية"
        sleep "$interval"
      done
      ;;
    *)
      print_once
      ;;
  esac
}

main "$@"

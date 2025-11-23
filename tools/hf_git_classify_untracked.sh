#!/usr/bin/env bash
# HyperFFactory – Git Untracked Classifier (v2)
# يصنّف ملفات git غير المتتبّعة إلى:
#  - CORE_FACTORY: ملفات/مجلدات تخص المصنع نفسه
#  - IMPORTED_SNAPSHOT: لقطات/أرشيف/مجلدات imported/backups/snapshots/docker
#  - EXTERNAL_SUITE: تخص smartfriend-suite / smartfrind / ffactory
#  - LOCAL_ENV: ملفات البيئة المحلية (.env / .venv / .hyperconfig ...)
#  - UNKNOWN: تحتاج مراجعة يدوية

set -euo pipefail

ROOT="/root/HyperFFactory"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "❌ هذا المسار ليس مستودع Git: $ROOT"
  exit 1
fi

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="reports/hf_git_untracked_classified_${TS}.log"
mkdir -p "$(dirname "$REPORT")"

echo "==================================================" | tee "$REPORT"
echo "🧩 HyperFFactory – Git Untracked Files Classification (v2)" | tee -a "$REPORT"
echo "ROOT : $ROOT" | tee -a "$REPORT"
echo "TIME : $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$REPORT"
echo "==================================================" | tee -a "$REPORT"
echo | tee -a "$REPORT"

# نقرأ فقط الملفات غير المتتبّعة (??)
mapfile -t UNTRACKED < <(git status --porcelain 2>/dev/null | awk '$1=="??"{sub(/^.. /,"");print}')

if [[ "${#UNTRACKED[@]}" -eq 0 ]]; then
  echo "لا توجد ملفات غير متتبّعة (git clean)." | tee -a "$REPORT"
  exit 0
fi

CORE_FACTORY=()
IMPORTED_SNAPSHOT=()
EXTERNAL_SUITE=()
LOCAL_ENV=()
UNKNOWN=()

is_prefix() {
  # is_prefix path prefix
  case "$1" in
    "$2"*) return 0 ;;
    *)     return 1 ;;
  esac
}

classify_path() {
  local path="$1"

  # 1) LOCAL_ENV – بيئة محلية
  if [[ "$path" == ".env" ]] || \
     [[ "$path" == ".hyperconfig" ]] || \
     [[ "$path" == ".venv" ]] || \
     is_prefix "$path" ".venv/" ; then
    LOCAL_ENV+=("$path")
    return
  fi

  # 2) IMPORTED_SNAPSHOT – imported / snapshots / docker / deep audits / secure
  if is_prefix "$path" "imported/opt/report/" || \
     is_prefix "$path" "imported/opt/COMPLETE_CODE_BACKUP" || \
     is_prefix "$path" "imported/opt/deepseek" || \
     is_prefix "$path" "imported/opt/sf_deep_audit_" || \
     is_prefix "$path" "imported/opt/secure" || \
     is_prefix "$path" "imported/opt/sf-venv" || \
     is_prefix "$path" "motd_backup_" || \
     is_prefix "$path" "backup/" || \
     is_prefix "$path" "archive/" || \
     [[ "$path" == *_backup_* ]] || \
     [[ "$path" == _root_conflicts_* ]]; then
    IMPORTED_SNAPSHOT+=("$path")
    return
  fi

  # 3) EXTERNAL_SUITE – smartfriend / smartfrind / ffactory داخل الشجرة
  if is_prefix "$path" "imported/opt/smartfriend-suite/" || \
     is_prefix "$path" "imported/opt/smartfrind/" || \
     is_prefix "$path" "imported/opt/ffactory/" || \
     is_prefix "$path" "opt/smartfriend-suite/" || \
     is_prefix "$path" "opt/smartfrind/" || \
     is_prefix "$path" "opt/ffactory/"; then
    EXTERNAL_SUITE+=("$path")
    return
  fi

  # 4) CORE_FACTORY – قلب HyperFFactory
  if is_prefix "$path" "db/" || \
     is_prefix "$path" "tools/" || \
     is_prefix "$path" "bin/" || \
     is_prefix "$path" "scripts/" || \
     is_prefix "$path" "plans/" || \
     [[ "$path" == "plan_status.md" ]] || \
     [[ "$path" == "PLAN_STATUS.md" ]] || \
     is_prefix "$path" "config/" || \
     is_prefix "$path" "data_lakehouse/" || \
     is_prefix "$path" "factories/" || \
     is_prefix "$path" "agents/" || \
     is_prefix "$path" "workers/" || \
     is_prefix "$path" "reports/" || \
     is_prefix "$path" "ai/" || \
     is_prefix "$path" "apps/" || \
     is_prefix "$path" "learning/" || \
     is_prefix "$path" "ops/" || \
     is_prefix "$path" "sql/" || \
     [[ "$path" == "ops.py" ]] || \
     [[ "$path" == "apps.py" ]] || \
     [[ "$path" == "self_learning_brain.py" ]] || \
     [[ "$path" == "simple_brain.py" ]] || \
     [[ "$path" == "awareness_system.py" ]] || \
     [[ "$path" == "live_brain_monitor.sh" ]] || \
     [[ "$path" == "structure.txt" ]]; then
    CORE_FACTORY+=("$path")
    return
  fi

  # 5) UNKNOWN – أي شيء آخر
  UNKNOWN+=("$path")
}

for p in "${UNTRACKED[@]}"; do
  classify_path "$p"
done

print_section() {
  local title="$1"
  shift
  local -n arr="$1"

  echo "--------------------------------------------------" | tee -a "$REPORT"
  echo "$title" | tee -a "$REPORT"
  echo "عدد العناصر: ${#arr[@]}" | tee -a "$REPORT"
  if [[ "${#arr[@]}" -eq 0 ]]; then
    echo "  (لا يوجد عناصر في هذه الفئة)" | tee -a "$REPORT"
  else
    for item in "${arr[@]}"; do
      echo "  - $item" | tee -a "$REPORT"
    done
  fi
  echo | tee -a "$REPORT"
}

print_section "📦 CORE_FACTORY – ملفات تخص HyperFFactory نفسه (مرشّحة للضم للريبو)" CORE_FACTORY
print_section "📥 IMPORTED_SNAPSHOT – imported / snapshots / backups / docker overlay" IMPORTED_SNAPSHOT
print_section "🌐 EXTERNAL_SUITE – smartfriend / smartfrind / ffactory داخل الشجرة" EXTERNAL_SUITE
print_section "🧪 LOCAL_ENV – ملفات بيئة محلية (.env / .venv / .hyperconfig)" LOCAL_ENV
print_section "❓ UNKNOWN – تحتاج قرار يدوي" UNKNOWN

echo "==================================================" | tee -a "$REPORT"
echo "تم حفظ التقرير في: $REPORT" | tee -a "$REPORT"

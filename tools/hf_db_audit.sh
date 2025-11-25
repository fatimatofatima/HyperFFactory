#!/usr/bin/env bash
set -euo pipefail

ROOT="/root/HyperFFactory"

echo "====================================================="
echo " HyperFFactory DB Audit"
echo " ROOT: $ROOT"
echo " TIME: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "====================================================="
echo

if [ ! -d "$ROOT" ]; then
  echo "خطأ: مجلد ROOT غير موجود: $ROOT" >&2
  exit 1
fi

# جمع كل ملفات .db (ملف عادي أو symlink) تحت الهايبر
mapfile -t HF_DBS < <(
  find "$ROOT" \( -type f -o -type l \) -name '*.db' 2>/dev/null | sort
)

printf '%-5s %-12s %-18s %s\n' "ID" "SCOPE" "TYPE" "PATH"
printf '%-5s %-12s %-18s %s\n' "----" "------------" "------------------" "----"

if [ "${#HF_DBS[@]}" -eq 0 ]; then
  echo "لا توجد أي ملفات .db داخل $ROOT"
  exit 0
fi

# عدادات
declare -A scope_counts
declare -A type_counts

id=0
for db in "${HF_DBS[@]}"; do
  ((id++))
  scope="HYPER"
  type="OTHER"

  case "$db" in
    "$ROOT"/db/identity/*.db)
      scope="CORE"; type="IDENTITY" ;;
    "$ROOT"/db/knowledge/*.db)
      scope="CORE"; type="KNOWLEDGE" ;;
    "$ROOT"/db/memory/*.db)
      scope="CORE"; type="MEMORY" ;;
    "$ROOT"/db/skills/*.db)
      scope="CORE"; type="SKILLS" ;;
    "$ROOT"/db/meta/hf_*.db)
      scope="META"; type="HF_META" ;;
    "$ROOT"/db/tasks/tasks.db)
      scope="LEGACY"; type="INTERNAL_TASKS" ;;
    "$ROOT"/db/quality.db)
      scope="LEGACY"; type="INTERNAL_QUALITY" ;;
    "$ROOT"/var/db/management/*.db)
      scope="SHADOW"; type="MGMT_SHADOW" ;;
  esac

  scope_counts["$scope"]=$(( ${scope_counts["$scope"]:-0} + 1 ))
  type_counts["$type"]=$(( ${type_counts["$type"]:-0} + 1 ))

  printf '%-5s %-12s %-18s %s\n' "$id" "$scope" "$type" "$db"
done

echo
echo "-----------------------------------------------------"
echo " Summary by SCOPE"
echo "-----------------------------------------------------"
for s in "${!scope_counts[@]}"; do
  printf "  - %-10s : %d\n" "$s" "${scope_counts[$s]}"
done

echo
echo "-----------------------------------------------------"
echo " Summary by TYPE"
echo "-----------------------------------------------------"
for t in "${!type_counts[@]}"; do
  printf "  - %-16s : %d\n" "$t" "${type_counts[$t]}"
done

echo
echo "-----------------------------------------------------"
echo " External DBs (SmartFriend Suite / SmartFrind Legacy)"
echo "-----------------------------------------------------"

check_external() {
  local label="$1"; shift
  local path
  for path in "$@"; do
    if [ -f "$path" ]; then
      printf '%-12s %s\n' "$label" "$path"
    else
      printf '%-12s %s (missing)\n' "$label" "$path"
    fi
  done
}

check_external "SF_SUITE" \
  "/opt/smartfriend-suite/var/db/smartfriend_unified.db" \
  "/opt/smartfriend-suite/var/db/active_memory.db"

check_external "SMARTFRIND" \
  "/var/lib/smartfrind/identity.db" \
  "/var/lib/smartfrind/memory.db"

echo
echo "ملاحظة:"
echo "  - CORE       = هوية / معرفة / ذاكرة / مهارات (داخل db/*)"
echo "  - META       = hf_* (إدارة / جودة / تعلّم / أخطاء / أنماط / OPS)"
echo "  - LEGACY     = قواعد داخل الهايبر لكن خارج الخدمة للكود الجديد"
echo "  - SHADOW     = var/db/management (طبقة إدارة ظل تجريبية)"
echo "  - HYPER/OTHER= أي DB أخرى داخل /root/HyperFFactory"
echo "  - External   = أنظمة خارجية (SmartFriend / SmartFrind) للتكامل فقط"

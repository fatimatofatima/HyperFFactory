#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){ echo; echo "=== $1 ==="; }

SUITE_DIR="/opt/smartfriend-suite"
FF_DIR="/opt/ffactory"

# جذور البحث عن الكود
SEARCH_ROOTS=()
[ -d "$SUITE_DIR" ] && SEARCH_ROOTS+=("$SUITE_DIR")
[ -d "$FF_DIR" ] && SEARCH_ROOTS+=("$FF_DIR")

# خدمات التعلّم في SmartFriend
SF_LEARNING_SERVICES=(
  sf-ingest
  sf-learn
  sf-learning
  sf-kb-build
  sf-fts-maint
  sf-spider
)

# خدمات تحليل/تعلّم في FFactory
FF_LEARNING_SERVICES=(
  ff-selfaware
  ff-doctor
)

log "===== SmartFriend Learning/Brain Stack – Audit ONLY (no changes) ====="
echo

########################################
# 1) ملخص قواعد البيانات (العقل)
########################################
section "1) قواعد البيانات (Brain Data Layer)"
for db in \
  "/opt/smartfriend-suite/var/db/memory.db" \
  "/opt/smartfriend-suite/var/db/active_memory.db" \
  "/opt/smartfriend-suite/var/db/smartfriend_unified.db" \
  "/opt/ffactory/var/db/ffactory.db" \
  "/opt/ffactory/var/db/brain.db"
do
  if [ -f "$db" ]; then
    size=$(du -h "$db" | cut -f1)
    echo " - $db ($size)"
  fi
done

if command -v sqlite3 >/dev/null 2>&1 && [ -f "/opt/smartfriend-suite/var/db/memory.db" ]; then
  echo
  echo ">> meta من memory.db:"
  sqlite3 "/opt/smartfriend-suite/var/db/memory.db" "SELECT key, value FROM meta ORDER BY key;" 2>/dev/null || true
fi

########################################
# 2) دالة مساعدة لفحص خدمة واحدة
########################################
inspect_service(){
  local name="$1"          # مثال: sf-learn
  local label="$2"         # مثال: SmartFriend / FFactory

  local svc="${name}.service"
  echo
  echo ">>> الخدمة: ${svc}  [${label}]"

  # هل الخدمة معرّفة في systemd ؟
  local unit_file
  unit_file=$(systemctl show -p FragmentPath --value "$svc" 2>/dev/null || true)

  if [ -z "$unit_file" ] || [ "$unit_file" = "n/a" ]; then
    echo "   - unit: غير معرّف في systemd (لا يوجد .service فعّال)"
    return 0
  fi

  echo "   - unit: ${unit_file}"

  # حالة التفعيل والتشغيل
  local enabled active
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
  active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")

  echo "   - enabled: ${enabled}"
  echo "   - active : ${active}"

  # ExecStart من ملف الـ unit
  if [ -f "$unit_file" ]; then
    local exec_line
    exec_line=$(grep -E '^ExecStart=' "$unit_file" 2>/dev/null || true)
    if [ -n "$exec_line" ]; then
      exec_line="${exec_line#ExecStart=}"
      echo "   - ExecStart: ${exec_line}"
    fi
  fi

  # بحث عن ملفات الكود المرتبطة
  if [ "${#SEARCH_ROOTS[@]}" -gt 0 ]; then
    echo "   - code hits (أول 3 ملفات تحتوي الاسم):"
    grep -R "$name" "${SEARCH_ROOTS[@]}" \
      --include="*.py" --include="*.sh" --include="*.service" \
      -m 3 2>/dev/null \
      | sed 's/^/      /' || echo "      لا يوجد تطابق واضح في مسارات البحث."
  else
    echo "   - code hits: لا توجد جذور بحث (SEARCH_ROOTS فارغة)."
  fi
}

########################################
# 3) خدمات SmartFriend للتعلّم
########################################
section "2) خدمات التعلّم في SmartFriend (sf-*)"

if [ "${#SF_LEARNING_SERVICES[@]}" -eq 0 ]; then
  echo "لا توجد خدمات محددة."
else
  for s in "${SF_LEARNING_SERVICES[@]}"; do
    inspect_service "$s" "SmartFriend"
  done
fi

########################################
# 4) خدمات FFactory المرتبطة بالعقل/التعلّم
########################################
section "3) خدمات تحليل/تعلّم في FFactory (ff-*)"

if [ "${#FF_LEARNING_SERVICES[@]}" -eq 0 ]; then
  echo "لا توجد خدمات محددة."
else
  for s in "${FF_LEARNING_SERVICES[@]}"; do
    inspect_service "$s" "FFactory"
  done
fi

########################################
# 5) ملخص تنفيذي سريع
########################################
section "4) ملخص تنفيذي (للتفعيل لاحقًا)"

printf "   %-18s | %-8s | %-10s | %-8s\n" "Service" "Layer" "Defined" "Active"
printf "   %-18s-+-%-8s-+-%-10s-+-%-8s\n" "------------------" "--------" "----------" "--------"

summ_line(){
  local name="$1"
  local layer="$2"
  local svc="${name}.service"

  local unit_file
  unit_file=$(systemctl show -p FragmentPath --value "$svc" 2>/dev/null || true)

  local defined="no"
  local active="unknown"
  if [ -n "$unit_file" ] && [ "$unit_file" != "n/a" ]; then
    defined="yes"
    active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  fi

  printf "   %-18s | %-8s | %-10s | %-8s\n" "$svc" "$layer" "$defined" "$active"
}

for s in "${SF_LEARNING_SERVICES[@]}"; do
  summ_line "$s" "SF"
done
for s in "${FF_LEARNING_SERVICES[@]}"; do
  summ_line "$s" "FF"
done

echo
log "انتهى فحص Stack العقل/التعلّم – لا تعديل تم، تقرير فقط."

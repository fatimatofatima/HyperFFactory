#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }
section(){ echo; echo "=== $1 ==="; }

SUITE_DIR="/opt/smartfriend-suite"
FF_DIR="/opt/ffactory"

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

# محاولة استخراج ExecStart من ملف الـ unit
get_exec_from_unit() {
  local unit_file="$1"
  if [ -z "$unit_file" ] || [ ! -f "$unit_file" ]; then
    echo "-"
    return 0
  fi
  # أول سطر ExecStart فقط
  local line
  line=$(grep -E '^ExecStart=' "$unit_file" 2>/dev/null | head -n1 || true)
  line="${line#ExecStart=}"
  # تقصير العرض
  echo "$line"
}

classify_root() {
  local exec_line="$1"
  if [[ "$exec_line" == *"$SUITE_DIR"* ]]; then
    echo "smartfriend-suite"
  elif [[ "$exec_line" == *"$FF_DIR"* ]]; then
    echo "ffactory"
  else
    echo "other"
  fi
}

inspect_service_block() {
  local name="$1"
  local layer="$2"  # SF / FF

  local svc="${name}.service"
  echo
  echo ">>> الخدمة: ${svc}  [${layer}]"

  local unit_file
  unit_file=$(systemctl show -p FragmentPath --value "$svc" 2>/dev/null || true)

  if [ -z "$unit_file" ] || [ "$unit_file" = "n/a" ]; then
    echo "   - unit     : غير معرّف في systemd (لا يوجد ملف خدمة فعّال)"
    echo "   - enabled  : unknown"
    echo "   - active   : unknown"
    echo "   - ExecStart: -"
    echo "   - root     : -"
    return 0
  fi

  echo "   - unit     : $unit_file"

  local enabled active
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
  active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")

  echo "   - enabled  : $enabled"
  echo "   - active   : $active"

  local exec_line
  exec_line=$(get_exec_from_unit "$unit_file")
  echo "   - ExecStart: ${exec_line:-"-"}"

  local root
  root=$(classify_root "$exec_line")
  echo "   - root     : $root"

  # hits للكود (3 فقط) من أجل التتبع
  echo "   - code hits (أول 3 ملفات تحتوي الاسم):"
  if [ -d "$SUITE_DIR" ] || [ -d "$FF_DIR" ]; then
    grep -R "$name" "$SUITE_DIR" "$FF_DIR" \
      --include="*.py" --include="*.sh" --include="*.service" \
      -m 3 2>/dev/null | sed 's/^/      /' || echo "      لا يوجد تطابق واضح."
  else
    echo "      لا توجد جذور بحث صالحة."
  fi
}

summary_row() {
  local name="$1"
  local layer="$2"

  local svc="${name}.service"
  local unit_file enabled active exec_line root

  unit_file=$(systemctl show -p FragmentPath --value "$svc" 2>/dev/null || true)
  if [ -z "$unit_file" ] || [ "$unit_file" = "n/a" ]; then
    enabled="unknown"
    active="unknown"
    exec_line="-"
    root="-"
  else
    enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
    active=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    exec_line=$(get_exec_from_unit "$unit_file")
    root=$(classify_root "$exec_line")
  fi

  # اختصار ExecStart للعرض
  local short_exec="-"
  if [ -n "$exec_line" ]; then
    short_exec=$(echo "$exec_line" | awk '{print $1}' )
  fi

  printf " %-20s | %-3s | %-8s | %-8s | %-18s | %s\n" \
    "$svc" "$layer" "$active" "$enabled" "$root" "$short_exec"
}

log "===== SmartFriend Learning / Brain Services – Matrix (READ ONLY) ====="

section "1) طبقة قواعد البيانات (Brain Data Layer)"
for db in \
  "/opt/smartfriend-suite/var/db/memory.db" \
  "/opt/smartfriend-suite/var/db/active_memory.db" \
  "/opt/smartfriend-suite/var/db/smartfriend_unified.db"
do
  if [ -f "$db" ]; then
    size=$(du -h "$db" | cut -f1)
    echo " - $db ($size)"
  fi
done

if command -v sqlite3 >/dev/null 2>&1 && [ -f "/opt/smartfriend-suite/var/db/memory.db" ]; then
  echo
  echo ">> meta من memory.db:"
  sqlite3 "/opt/smartfriend-suite/var/db/memory.db" \
    "SELECT key, value FROM meta ORDER BY key;" 2>/dev/null || true
fi

section "2) تفاصيل كل خدمة تعلم/عقل"

for s in "${SF_LEARNING_SERVICES[@]}"; do
  inspect_service_block "$s" "SF"
done

for s in "${FF_LEARNING_SERVICES[@]}"; do
  inspect_service_block "$s" "FF"
done

section "3) Matrix ملخّص للتفعيل المستقبلي"

printf " %-20s | %-3s | %-8s | %-8s | %-18s | %s\n" \
  "SERVICE" "L" "ACTIVE" "ENABLED" "ROOT" "EXEC"
printf " %-20s-+-%-3s-+-%-8s-+-%-8s-+-%-18s-+-%s\n" \
  "--------------------" "---" "--------" "--------" "------------------" "--------------------"

for s in "${SF_LEARNING_SERVICES[@]}"; do
  summary_row "$s" "SF"
done

for s in "${FF_LEARNING_SERVICES[@]}"; do
  summary_row "$s" "FF"
done

echo
log "انتهى فحص Stack العقل/التعلّم – بدون أي تغييرات (تقرير فقط)."

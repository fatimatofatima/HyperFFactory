#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

log(){ echo "[$(date '+%F %T')] $*"; }

HEADER_PRINTED=0

print_header() {
  if [ "$HEADER_PRINTED" -eq 0 ]; then
    printf "\n%-28s | %-8s | %-8s | %-18s | %-18s | %s\n" "SERVICE" "ACTIVE" "ENABLED" "FAMILY" "ROOT_PATH" "EXEC_START"
    printf "%-28s-+-%-8s-+-%-8s-+-%-18s-+-%-18s-+-%s\n" \
      "----------------------------" "--------" "--------" "------------------" "------------------" "----------------------------"
    HEADER_PRINTED=1
  fi
}

classify_family() {
  local exec="$1"
  if [[ "$exec" == *"/opt/smartfriend-suite"* ]]; then
    echo "smartfriend-suite"
  elif [[ "$exec" == *"/opt/ffactory"* ]]; then
    echo "ffactory"
  elif [[ "$exec" == *"/srv/factory"* ]]; then
    echo "ffactory-legacy"
  else
    echo "other"
  fi
}

classify_root() {
  local exec="$1"
  if [[ "$exec" == *"/opt/smartfriend-suite"* ]]; then
    echo "/opt/smartfriend-suite"
  elif [[ "$exec" == *"/opt/ffactory"* ]]; then
    echo "/opt/ffactory"
  elif [[ "$exec" == *"/srv/factory"* ]]; then
    echo "/srv/factory"
  else
    echo "-"
  fi
}

log "===== Inventory & Classification of sf-* / ff-* services by path & state ====="

# 1) جمع كل ملفات الوحدات من المسارات الرسمية
UNIT_FILES=()
while IFS= read -r f; do
  UNIT_FILES+=("$f")
done < <(find /etc/systemd/system /lib/systemd/system \
           -maxdepth 1 -type f \( -name "sf-*.service" -o -name "ff-*.service" \) 2>/dev/null | sort)

if [ "${#UNIT_FILES[@]}" -eq 0 ]; then
  log "❌ لا توجد أي وحدات systemd من نوع sf-*.service أو ff-*.service."
  exit 0
fi

log "وجدت ${#UNIT_FILES[@]} ملف خدمة (sf-/ff-). سيتم التصنيف الآن..."
print_header

for unit_file in "${UNIT_FILES[@]}"; do
  service_name="$(basename "$unit_file")"

  # تأكيد الاسم عند systemctl (بدون المسار)
  svc="${service_name}"

  # حالة التشغيل
  active_state=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
  enabled_state=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")

  # تفاصيل من systemd show
  fragment_path=$(systemctl show -p FragmentPath "$svc" 2>/dev/null | sed 's/^FragmentPath=//')
  exec_start_raw=$(systemctl show -p ExecStart "$svc" 2>/dev/null | sed 's/^ExecStart=//')

  # تنظيف ExecStart (نأخذ أول أمر فقط لو فيه سطر طويل)
  exec_short="$exec_start_raw"
  # لو فيه ; نفصل على أول أمر
  if [[ "$exec_short" == *";"* ]]; then
    exec_short="${exec_short%%;*}"
  fi
  # إزالة المسافات الزائدة
  exec_short="$(echo "$exec_short" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  family="$(classify_family "$exec_short")"
  root_path="$(classify_root "$exec_short")"

  printf "%-28s | %-8s | %-8s | %-18s | %-18s | %s\n" \
    "$svc" "$active_state" "$enabled_state" "$family" "$root_path" "$exec_short"
done

echo
log "ملحوظة:"
echo "- FAMILY: تصنيف منطقي حسب مسار التنفيذ (smartfriend-suite / ffactory / other)."
echo "- ROOT_PATH: الجذر الفعلي المستنتج من ExecStart."
echo "- ACTIVE/ENABLED حسب systemctl (is-active / is-enabled)."
echo
log "===== DONE: Services inventory by path & state ====="

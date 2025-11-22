#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }

REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/sf_suite_start_all_$(date +%Y%m%d_%H%M%S).log"

teeout(){ tee -a "$REPORT"; }

log "=== SmartFriend Suite – تشغيل كل خدمات السيوت (بدون لمس ffactory) ===" | teeout
echo | teeout

PATTERNS=("sf-*.service" "smartfrind-*.service" "smartfriend-*.service")

UNITS=()
for p in "${PATTERNS[@]}"; do
  while read -r name state; do
    [ -z "$name" ] && continue
    UNITS+=("$name")
  done < <(systemctl list-unit-files "$p" --no-legend 2>/dev/null | awk '{print $1" "$2}')
done

UNITS=($(printf "%s\n" "${UNITS[@]}" | sort -u))

if [ "${#UNITS[@]}" -eq 0 ]; then
  warn "لا توجد وحدات سيوت لبدء تشغيلها." | teeout
  exit 0
fi

log "سيتم محاولة enable + restart لكل وحدات السيوت التالية:" | teeout
for u in "${UNITS[@]}"; do
  echo "  - $u" | teeout
done
echo | teeout

SUCCESS=()
FAILED=()

for unit in "${UNITS[@]}"; do
  echo "------------------------------------------------------------" | teeout
  log "معالجة $unit ..." | teeout

  # حماية إضافية: لا نلمس أي شيء يشبه ffactory/factory
  case "$unit" in
    ff-*|ffactory-*|factory-*)
      warn "  تخطي $unit لأنه يبدو تابعاً لـ ffactory/factory." | teeout
      continue
      ;;
  esac

  if systemctl enable "$unit" &>/dev/null; then
    ok "  enable $unit" | teeout
  else
    warn "  فشل enable لـ $unit (قد يكون template أو static)." | teeout
  fi

  if systemctl restart "$unit" &>/dev/null; then
    ok "  restart $unit" | teeout
    SUCCESS+=("$unit")
  else
    warn "  فشل restart لـ $unit، راجع: journalctl -u $unit -n 50 --no-pager" | teeout
    FAILED+=("$unit")
  fi
done

echo | teeout
log "ملخص التشغيل:" | teeout

if [ "${#SUCCESS[@]}" -gt 0 ]; then
  ok "الخدمات التي اُعتبرت شغّالة بنجاح:" | teeout
  for u in "${SUCCESS[@]}"; do
    echo "  + $u" | teeout
  done
else
  warn "لا توجد خدمات نجح تشغيلها (حسب ما رصد السكربت)." | teeout
fi

if [ "${#FAILED[@]}" -gt 0 ]; then
  warn "الخدمات التي فشل تشغيلها وتحتاج مراجعة يدوية:" | teeout
  for u in "${FAILED[@]}"; do
    echo "  - $u" | teeout
  done
  echo | teeout
  echo "استخدم مثلاً:" | teeout
  echo "  journalctl -u <service> -n 50 --no-pager" | teeout
fi

ok "انتهى السكربت. التقرير في: $REPORT" | teeout

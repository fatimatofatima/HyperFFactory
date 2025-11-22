#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log()  { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
ok()   { echo -e "${GREEN}[$(date '+%F %T')] [OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date '+%F %T')] [WARN]${NC} $*" >&2; }

REPORT_DIR="/root/sf_reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/sf_suite_units_desymlink_$(date +%Y%m%d_%H%M%S).log"

teeout(){ tee -a "$REPORT"; }

log "=== SmartFriend Suite – فكّ symlinks لوحدات السيوت فقط (بدون لمس ffactory/factory) ===" | teeout
echo | teeout

cd /etc/systemd/system

PATTERNS=("sf-*.service" "smartfriend-*.service" "smartfrind-*.service")

changed=()
skipped=()

for pat in "${PATTERNS[@]}"; do
  for unit in $pat; do
    [ -e "$unit" ] || continue

    # حماية ffactory / factory
    if echo "$unit" | grep -qiE 'ffactory|factory-gw'; then
      skipped+=("$unit (ffactory/factory)")
      continue
    fi

    if [ -L "$unit" ]; then
      target="$(readlink -f "$unit" || true)"

      if [ -z "$target" ] || [ ! -f "$target" ]; then
        warn "تخطي $unit: symlink مكسور أو الهدف غير موجود" | teeout
        skipped+=("$unit (broken symlink)")
        continue
      fi

      tmp="$(mktemp "/tmp/${unit}.XXXXXX")"
      cat "$unit" > "$tmp"
      rm -f "$unit"
      mv "$tmp" "$unit"

      ok "تحويل $unit من symlink إلى ملف عادي (كان يشير إلى: $target)" | teeout
      changed+=("$unit -> $target")
    else
      skipped+=("$unit (already regular)")
    fi
  done
done

log "إعادة تحميل systemd..." | teeout
systemctl daemon-reload

echo | teeout
log "ملخّص:" | teeout

if [ "${#changed[@]}" -gt 0 ]; then
  echo "  [OK] وحدات تم فكّ symlink عنها:" | teeout
  for c in "${changed[@]}"; do
    echo "    + $c" | teeout
  done
else
  echo "  [OK] لا توجد symlinks في وحدات السيوت." | teeout
fi

if [ "${#skipped[@]}" -gt 0 ]; then
  echo "  [INFO] وحدات تم تخطيها:" | teeout
  for s in "${skipped[@]}"; do
    echo "    - $s" | teeout
  done
fi

log "انتهى. التقرير في: $REPORT" | teeout

#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log()   { echo -e "${BLUE}[$(date '+%F %T')]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$(date '+%F %T')] [WARN] ${NC}$*" >&2; }
error() { echo -e "${RED}[$(date '+%F %T')] [ERROR] ${NC}$*" >&2; }
ok()    { echo -e "${GREEN}[$(date '+%F %T')] [OK] ${NC}$*"; }

if [[ "$EUID" -ne 0 ]]; then
  error "يجب تشغيل السكربت بصلاحيات root."
  exit 1
fi

log "=== خريطة جميع الخدمات على السيرفر: حالة + موقع ملف الوحدة + أمر التشغيل ==="

# 1) إحصائيات عامة
log "1) إحصائيات عامة عن الخدمات:"
TOTAL=$(systemctl list-unit-files --type=service --no-legend 2>/dev/null | wc -l || echo 0)
ACTIVE=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l || echo 0)
FAILED=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null | wc -l || echo 0)

echo "  • إجمالي ملفات الخدمات (service): $TOTAL"
echo "  • الخدمات النشطة (running):       $ACTIVE"
echo "  • الخدمات الفاشلة (failed):       $FAILED"
echo

# 2) قائمة بكل الخدمات مع الحالة والموقع
log "2) تفاصيل كل خدمة (قد يكون الإخراج طويلاً):"
echo "--------------------------------------------------------------------------------"
printf "%-45s | %-8s | %-8s | %-45s\n" "UNIT" "ACTIVE" "SUB" "FRAGMENT (ملف الخدمة)"
echo "--------------------------------------------------------------------------------"

# نجلب كل أسماء الوحدات (service) فقط
mapfile -t SERVICES < <(systemctl list-unit-files --type=service --no-legend 2>/dev/null | awk '{print $1}' | sort)

for unit in "${SERVICES[@]}"; do
  # الحالة العامة
  ACTIVE_STATE=$(systemctl is-active "$unit" 2>/dev/null || echo "unknown")
  SUB_STATE=$(systemctl show -p SubState --value "$unit" 2>/dev/null || echo "-")

  # مسار ملف الـ service
  FRAG=$(systemctl show -p FragmentPath --value "$unit" 2>/dev/null || echo "-")

  printf "%-45s | %-8s | %-8s | %-45s\n" "$unit" "$ACTIVE_STATE" "$SUB_STATE" "$FRAG"
done

echo
log "3) تفاصيل موسّعة للخدمات المهمة (SmartFriend / SmartFrind / ffactory/factory):"

expand_group() {
  local pattern="$1"
  local title="$2"

  echo
  echo "==================== $title ===================="
  mapfile -t GSRV < <(printf '%s\n' "${SERVICES[@]}" | grep -E "$pattern" || true)
  if [[ "${#GSRV[@]}" -eq 0 ]]; then
    echo "  (لا توجد خدمات مطابقة للنمط: $pattern)"
    return
  fi

  for unit in "${GSRV[@]}"; do
    echo
    echo "► الخدمة: $unit"
    echo "---------------------------------------------"
    systemctl status "$unit" --no-pager -l 2>/dev/null | head -n 15 || echo "  (لا يمكن جلب status للخدمة)"
    echo

    # إظهار تفاصيل الموقع وأمر التشغيل
    FRAG=$(systemctl show -p FragmentPath --value "$unit" 2>/dev/null || echo "-")
    SRC=$(systemctl show -p SourcePath   --value "$unit" 2>/dev/null || echo "-")
    WD=$(systemctl show -p WorkingDirectory --value "$unit" 2>/dev/null || echo "-")
    EXEC=$(systemctl show -p ExecStart --value "$unit" 2>/dev/null || echo "-")

    echo "  ملف الخدمة (FragmentPath): $FRAG"
    echo "  ملف المصدر (SourcePath):   $SRC"
    echo "  WorkingDirectory:          $WD"
    echo "  ExecStart:                 $EXEC"
    echo "---------------------------------------------"
  done
}

# SmartFriend / SmartFrind
expand_group '^sf-|^smartfrind-' "خدمات SmartFriend / SmartFrind"

# ffactory / factory
expand_group '^ff-|^factory-' "خدمات ffactory / factory (للمراجعة فقط بدون تغيير)"

echo
ok "اكتمل فحص جميع الخدمات. يمكن مراجعة التقرير من هذا الإخراج أو من ملف اللوج."
